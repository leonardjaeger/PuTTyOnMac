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

    var onOutput: ((ArraySlice<UInt8>) -> Void)? {
        get { process.onOutput }
        set { process.onOutput = newValue }
    }
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
    private let puttyDirectory: @MainActor () throws -> PuTTYDirectory

    /// `puttyDirectory` nur für Tests ändern (eigener Ordner statt Application Support, RL 3.9).
    init(endpoint: Endpoint, connectionProtocol: ConnectionProtocol,
         puttyDirectory: @escaping @MainActor () throws -> PuTTYDirectory = AppIdentity.puttyDirectory) throws(InputError) {
        target = .quick(endpoint, connectionProtocol)
        self.puttyDirectory = puttyDirectory
        quickSession = try SessionFile.quickConnect(to: endpoint, using: connectionProtocol)
        sessionName = AppIdentity.quickSessionPrefix + UUID().uuidString
    }

    init(savedSession name: String,
         puttyDirectory: @escaping @MainActor () throws -> PuTTYDirectory = AppIdentity.puttyDirectory) throws(InputError) {
        try SessionName.check(name, reservedPrefix: AppIdentity.quickSessionPrefix)
        target = .saved(name)
        self.puttyDirectory = puttyDirectory
        quickSession = nil
        sessionName = name
    }

    /// Dieselbe Verbindung noch einmal (neue Schnellsitzung bzw. dieselbe gespeicherte Sitzung).
    func again() throws(InputError) -> Connection {
        switch target {
        case .quick(let endpoint, let connectionProtocol):
            try Connection(endpoint: endpoint, connectionProtocol: connectionProtocol, puttyDirectory: puttyDirectory)
        case .saved(let name):
            try Connection(savedSession: name, puttyDirectory: puttyDirectory)
        }
    }

    /// Gefahren, die vor jedem Verbinden bestätigt werden müssen (S4), auch aus Sitzungen, die als SSH-Proxy geladen
    /// werden. Wirft, wenn eine beteiligte Sitzung nicht lesbar ist: dann nicht verbinden (plink läse sie trotzdem).
    func warningsRequiringConfirmation() throws -> [SessionWarning] {
        guard quickSession == nil else { return [] }
        let directory: PuTTYDirectory = try puttyDirectory()
        return try SessionWarning.requiringConfirmation(for: try directory.read(sessionNamed: sessionName)) { name in
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
        do {
            directory = try puttyDirectory()
            if let quickSession { try directory.write(quickSession, sessionName: sessionName) }
            command = try PlinkCommand(sessionName: sessionName, puttyDirectory: directory.url.path,
                                       parentEnvironment: ProcessInfo.processInfo.environment)
        } catch {
            throw TerminalProcess.Failure(message: "Sitzung konnte nicht vorbereitet werden: \(error.localizedDescription)")
        }
        let temporary: String? = quickSession == nil ? nil : sessionName
        process.onExit = { [weak self] status in
            if let temporary { directory.removeSession(named: temporary) }
            AppLog.connection.info("Verbindung beendet, Status \(status, privacy: .public)")
            guard let self else { return }
            // Selbst getrennt: kein „Signal 1“ anzeigen
            self.onEnd?(self.hungUpByUser ? "Verbindung getrennt." : TerminalProcess.describe(status: status))
        }
        do {
            try process.start(executable: AppIdentity.plinkPath, arguments: command.arguments,
                              environment: command.environment, columns: columns, rows: rows)
        } catch {
            if let temporary { directory.removeSession(named: temporary) }
            process.onExit = nil
            throw error
        }
        AppLog.connection.info("Verbindung gestartet zu \(self.displayName, privacy: .private(mask: .hash))")
    }

    func send(_ data: ArraySlice<UInt8>) { process.send(data) }
    func resize(columns: Int, rows: Int) { process.resize(columns: columns, rows: rows) }
    func hangUp() {
        hungUpByUser = process.isRunning
        process.hangUp()
    }
}
