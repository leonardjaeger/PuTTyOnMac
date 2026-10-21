import Foundation
import TunnelTerminalCore

/// Eine Verbindung eines Tabs. Schnellverbindung: schreibt eine vorübergehende Sitzung in den PuTTY-Ordner und
/// entfernt sie wieder, sobald plink beendet ist. Gespeicherte Sitzung: plink lädt sie direkt. Immer `-load` (S3).
final class Connection {
    enum Target: Equatable {
        case quick(Endpoint, ConnectionProtocol)
        case saved(String)
    }

    let target: Target

    var onOutput: ((ArraySlice<UInt8>) -> Void)?
    /// Text für den Hinweis bei Verbindungsende.
    var onEnd: ((String) -> Void)?

    var isRunning: Bool { process.isRunning }

    /// Fenstertitel: Adresse bzw. Name der gespeicherten Sitzung.
    var displayName: String {
        switch target {
        case .quick(let endpoint, _): endpoint.displayName
        case .saved(let name): name
        }
    }

    /// Adresse und Protokoll einer Schnellverbindung (zum Vorbelegen eines neuen Tabs).
    var quickAddress: (text: String, connectionProtocol: ConnectionProtocol)? {
        if case .quick(let endpoint, let connectionProtocol) = target { (endpoint.displayName, connectionProtocol) } else { nil }
    }

    /// Nur bei Schnellverbindungen: die vorübergehende Sitzung.
    private let quickSession: SessionFile?
    private let sessionName: String
    private let process: TerminalProcess = TerminalProcess()
    private var hungUpByUser: Bool = false
    /// PuTTY-Ordner der Sitzung (auch für die Dateiübertragung, M6).
    let puttyDirectory: @MainActor () throws -> PuTTYDirectory
    /// Schlüsselbund für gespeicherte Passwörter; `nil` bei Schnellverbindungen und „ohne gespeichertes Passwort“.
    private let passwords: PasswordStore?
    private var rejectionWatch: RejectedPasswordWatch = RejectedPasswordWatch()

    /// plink hat das gespeicherte Passwort abgelehnt (falsches Passwort oder zweiter Faktor, M0 B12): dann bietet das
    /// Fenster „Ohne gespeichertes Passwort verbinden“ an. Ein Server könnte den Text auch selbst ausgeben – mehr als
    /// dieses Angebot bewirkt er nicht. Gilt nur, wenn plink danach mit einem Fehler endet und man nicht selbst trennt.
    private(set) var storedPasswordRejected: Bool = false
    /// Diese Verbindung übergibt ein gespeichertes Passwort an plink.
    private(set) var usesStoredPassword: Bool = false
    /// Sitzungsprotokoll der App (M4), solange die Verbindung läuft; nur für gespeicherte Sitzungen mit `LogType`.
    private(set) var log: SessionLogWriter?
    private let logFolder: URL
    /// Einstellungen, mit denen plink zuletzt gestartet ist: Dateiübertragungen (M6) nutzen dieselbe Sitzung wie das
    /// Terminal, auch wenn sie inzwischen im Editor geändert wurde (gilt wie bei Tunneln ab dem nächsten Verbinden).
    private(set) var startedSettings: SessionFile?
    /// Lokale Ports der Weiterleitungen, die beim Start schon belegt waren (M5): plink meldet das nur mit `-v`.
    private(set) var busyLocalPorts: [Int] = []

    /// `puttyDirectory` nur für Tests ändern (eigener Ordner statt Application Support, RL 3.9).
    init(endpoint: Endpoint, connectionProtocol: ConnectionProtocol,
         puttyDirectory: @escaping @MainActor () throws -> PuTTYDirectory = AppIdentity.puttyDirectory) throws(InputError) {
        target = .quick(endpoint, connectionProtocol)
        self.puttyDirectory = puttyDirectory
        quickSession = try SessionFile.quickConnect(to: endpoint, using: connectionProtocol)
        sessionName = AppIdentity.quickSessionPrefix + UUID().uuidString
        passwords = nil
        logFolder = SessionLogWriter.folder
    }

    /// `passwords`: `nil` verbindet ohne gespeichertes Passwort (plink fragt im Terminal).
    /// `logFolder` nur für Tests ändern.
    init(savedSession name: String,
         puttyDirectory: @escaping @MainActor () throws -> PuTTYDirectory = AppIdentity.puttyDirectory,
         passwords: PasswordStore? = AppIdentity.passwords,
         logFolder: URL = SessionLogWriter.folder) throws(InputError) {
        try SessionName.check(name, reservedPrefix: AppIdentity.quickSessionPrefix)
        target = .saved(name)
        self.puttyDirectory = puttyDirectory
        quickSession = nil
        sessionName = name
        self.passwords = passwords
        self.logFolder = logFolder
    }

    /// Dieselbe Verbindung noch einmal (neue Schnellsitzung bzw. dieselbe gespeicherte Sitzung).
    /// `withStoredPassword: false` nach einem abgelehnten Passwort: plink fragt dann selbst (z. B. für 2FA).
    func again(withStoredPassword: Bool = true) throws(InputError) -> Connection {
        switch target {
        case .quick(let endpoint, let connectionProtocol):
            try Connection(endpoint: endpoint, connectionProtocol: connectionProtocol, puttyDirectory: puttyDirectory)
        case .saved(let name):
            try Connection(savedSession: name, puttyDirectory: puttyDirectory, passwords: withStoredPassword ? passwords : nil,
                           logFolder: logFolder)
        }
    }

    /// Für den Inspektor: Die Sitzung hat ein gespeichertes Passwort (fragt den Schlüsselbund nicht nach dem Inhalt).
    var hasStoredPassword: Bool {
        if case .saved(let name) = target, let passwords { return passwords.contains(session: name) }
        return false
    }

    /// Gefahren, die vor jedem Verbinden bestätigt werden müssen (S4), auch aus Sitzungen, die als SSH-Proxy geladen
    /// werden. Wirft, wenn eine beteiligte Sitzung nicht lesbar ist: dann nicht verbinden (plink läse sie trotzdem).
    /// `file`: eine schon gelesene Fassung der Sitzung (Dateiübertragung: die beim Start, `transferSettings`).
    func warningsRequiringConfirmation(for file: SessionFile? = nil) throws -> [SessionWarning] {
        guard quickSession == nil else { return [] }
        let directory: PuTTYDirectory = try puttyDirectory()
        return try SessionWarning.requiringConfirmation(for: try file ?? directory.read(sessionNamed: sessionName),
                                                      named: sessionName) { name in
            directory.exists(sessionNamed: name) ? try directory.read(sessionNamed: name) : nil
        }
    }

    /// Einstellungen für den Inspektor: die Schnellsitzung bzw. die gespeicherte Sitzung (`nil`, wenn nicht lesbar).
    func settings() -> SessionFile? {
        if let quickSession { return quickSession }
        return try? puttyDirectory().read(sessionNamed: sessionName)
    }

    /// Startet plink. Fehler kommen als lesbarer Text zurück.
    func start(columns: Int, rows: Int) throws(TerminalProcess.Failure) {
        let directory: PuTTYDirectory
        let command: PlinkCommand
        let secret: Data?
        let saved: SessionFile?
        do {
            directory = try puttyDirectory()
            if let quickSession { try directory.write(quickSession, sessionName: sessionName) }
            saved = quickSession == nil ? try? directory.read(sessionNamed: sessionName) : nil
            startedSettings = quickSession ?? saved
            secret = storedPassword(from: saved)
            command = try PlinkCommand(sessionName: sessionName, puttyDirectory: directory.url.path,
                                       parentEnvironment: ProcessInfo.processInfo.environment,
                                       passwordFromPipe: secret != nil)
            if let saved, saved.connectionProtocol == .serial, saved.serialLine.isEmpty {
                throw TerminalProcess.Failure(message: "Kein serielles Gerät gewählt – im Sitzungs-Editor eines wählen.")
            }
            if saved?.sessionLogEnabled == true { openLog() }
        } catch let failure as TerminalProcess.Failure {
            throw failure
        } catch {
            throw TerminalProcess.Failure(message: "Sitzung konnte nicht vorbereitet werden: \(error.localizedDescription)")
        }
        if let saved, saved.connectionProtocol == .ssh {
            busyLocalPorts = saved.localListenPorts.filter(PortCheck.isInUse)
            for port in busyLocalPorts {
                note("Lokaler Port \(port) ist schon belegt – diese Weiterleitung richtet plink nicht ein.")
            }
        }
        let temporary: String? = quickSession == nil ? nil : sessionName
        process.onOutput = { [weak self] bytes in
            guard let self else { return }
            if self.usesStoredPassword { self.rejectionWatch.scan(bytes) }
            if let log = self.log, !log.write(bytes) {
                self.log = nil   // Grenze erreicht: Datei schließen, Hinweis im Terminal, Statuszeile beim nächsten Verbinden
                log.close()
                self.note("Sitzungsprotokoll angehalten: 1 GiB erreicht.")
            }
            self.onOutput?(bytes)
        }
        process.onExit = { [weak self] status in
            if let temporary { directory.removeSession(named: temporary) }
            AppLog.connection.info("Verbindung beendet, Status \(status, privacy: .public)")
            guard let self else { return }
            self.log?.close()
            self.log = nil
            self.storedPasswordRejected = self.rejectionWatch.found && !self.hungUpByUser && status != 0
            // Selbst getrennt: kein „Signal 1“ anzeigen
            if self.hungUpByUser {
                self.onEnd?("Verbindung getrennt.")
            } else if self.storedPasswordRejected {
                self.onEnd?("Das gespeicherte Passwort wurde nicht angenommen.")
            } else {
                self.onEnd?(TerminalProcess.describe(status: status))
            }
        }
        do {
            try process.start(executable: AppIdentity.plinkPath, arguments: command.arguments,
                              environment: command.environment, columns: columns, rows: rows, secret: secret)
        } catch {
            if let temporary { directory.removeSession(named: temporary) }
            process.onExit = nil
            log?.close()
            log = nil
            throw error
        }
        AppLog.connection.info("Verbindung gestartet zu \(self.displayName, privacy: .private(mask: .hash))")
    }

    /// Sitzungsprotokoll öffnen; scheitert es, sagt ein Hinweis im Terminal warum (die Verbindung läuft trotzdem).
    private func openLog() {
        do {
            log = try SessionLogWriter(sessionName: sessionName, folder: logFolder)
        } catch {
            note("Sitzungsprotokoll nicht möglich: \(error.message)")
        }
    }

    /// Hinweis der App im Terminal (gedimmt), nicht vom Server.
    private func note(_ text: String) {
        let line: String = "\u{1B}[2m[\(AppIdentity.name)] \(text)\u{1B}[0m\r\n"
        onOutput?(ArraySlice(Array(line.utf8)))
    }

    /// Passwort aus dem Schlüsselbund, nur wenn es zum aktuellen Ziel der Sitzung gehört (S1). Gehört es zu einem
    /// anderen Ziel, sagt ein Hinweis im Terminal, warum plink fragt.
    private func storedPassword(from file: SessionFile?) -> Data? {
        guard let passwords, case .saved(let name) = target,
              let file, let passwordTarget = file.passwordTarget else { return nil }
        switch passwords.lookup(session: name, target: passwordTarget) {
        case .found(let data):
            // Bewusst nicht überschrieben (Härtung): Der Schlüsselbund liefert unveränderliche Daten; Überschreiben ginge
            // nur mit einer veralteten Schnittstelle, und Kopien in securityd, im Pipe-Puffer und in plink blieben
            // trotzdem. Es lebt nur bis nach dem Start; Hardened Runtime ohne get-task-allow schützt
            // den Speicher vor anderen Prozessen.
            usesStoredPassword = true
            return data
        case .otherTarget:
            note("Gespeichertes Passwort nicht verwendet: Es gehört zu einem anderen Benutzer, Server oder Port. "
                 + "In der Sitzung neu sichern.")
            return nil
        case .none:
            return nil
        }
    }

    /// Sitzung für Dateiübertragungen: die beim letzten Start (sonst die gespeicherte bzw. die Schnellsitzung).
    var transferSettings: SessionFile? { startedSettings ?? settings() }

    /// Passwort aus dem Schlüsselbund für pscp (M6): nur, wenn es zum Ziel der Sitzung gehört (S1).
    func storedPasswordForTransfer() -> Data? {
        guard let passwords, case .saved(let name) = target, let passwordTarget = transferSettings?.passwordTarget,
              case .found(let data) = passwords.lookup(session: name, target: passwordTarget) else { return nil }
        return data
    }

    func send(_ data: ArraySlice<UInt8>) { process.send(data) }
    func resize(columns: Int, rows: Int) { process.resize(columns: columns, rows: rows) }
    func hangUp() {
        hungUpByUser = process.isRunning
        process.hangUp()
    }
}

/// Erkennt plinks Meldung über ein abgelehntes gespeichertes Passwort, auch wenn sie über zwei Lese-Blöcke verteilt
/// ankommt. Behält dafür nur das Ende der Ausgabe (eine Meldungslänge minus eins).
struct RejectedPasswordWatch {
    private static let message: [UInt8] = Array("Configured password was not accepted".utf8)
    private var recent: [UInt8] = []
    private(set) var found: Bool = false

    mutating func scan(_ bytes: ArraySlice<UInt8>) {
        guard !found else { return }
        recent.append(contentsOf: bytes)
        if recent.firstRange(of: Self.message) != nil {
            found = true
            recent = []
            return
        }
        let keep: Int = Self.message.count - 1
        if recent.count > keep { recent.removeFirst(recent.count - keep) }
    }
}
