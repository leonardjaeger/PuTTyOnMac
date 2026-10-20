import AppKit
import CoreServices
import Darwin
import TunnelTerminalCore

/// Dateiübertragung eines Tabs (M6; Plan 3.1: Inspektor „Dateien“, Symbolleiste „Hochladen“, Ziehen aufs Terminal) über
/// pscp mit der Sitzung des Tabs. Gemessenes Verhalten von pscp: docs/M6-Machbarkeit.md.
///
/// - pscp bekommt eine vorübergehende Kopie der Sitzung mit eingetragenem Benutzer – nennt die Sitzung keinen, fragt die
///   App, denn pscp nähme still den Benutzer dieses Macs – und läuft wie plink an einem eigenen PTY (`TerminalProcess`, S8).
/// - Passwort aus dem Schlüsselbund wie bei plink oder, wenn der Server eines verlangt, einmal abgefragt; beides nur über die
///   Pipe (`-pwfile /dev/fd/3`, S1) und nie gespeichert. Mit Proxy oder festen Hostschlüsseln keines (wie M3).
/// - Hochladen: erst den Zielordner auflisten (gibt es ihn, gibt es gleichnamige Dateien? → Rückfrage), dann je Datei ein Lauf.
/// - Herunterladen: Namen und Ordner wählt man im Sichern-Dialog (der fragt selbst vor dem Ersetzen). pscp schreibt in eine
///   versteckte Teildatei daneben, erst nach Erfolg ersetzt sie die Zieldatei; bei Abbruch oder Fehler ist sie wieder weg.
final class FileTransferController {
    let model: FileTransferModel = FileTransferModel()
    /// Fenster und Verbindung des Tabs.
    var window: () -> NSWindow? = { nil }
    var connection: () -> Connection? = { nil }
    /// Rückfragen am Fenster; nur Tests ersetzen sie.
    lazy var prompts: TransferPrompts = .window { [weak self] in self?.window() }
    /// Vor dem Start: Inspektor einblenden (dort stehen Fortschritt und „Abbrechen“).
    var revealInspector: (() -> Void)?

    private let pscpPath: String
    private var job: Job?
    /// Erfragter Benutzer (Sitzung ohne Benutzer) und zuletzt gewählte Ordner, je Tab.
    private var askedUser: String = ""
    private var remoteFolder: String = ""
    private var downloadFolder: URL?

    /// Höchstens so viel Ausgabe je Lauf behalten: Für Fortschritt und Meldung reicht das Ende; die Ordnerauflistung
    /// braucht alles, sonst fehlten Namen und pscp überschriebe still (Code-Review M6).
    private static let outputLimit: Int = 16_384
    private static let listingLimit: Int = 16 << 20

    /// `pscpPath` nur für Tests ändern (nie ein fremder Build, S7).
    init(pscpPath: String = AppIdentity.pscpPath) {
        self.pscpPath = pscpPath
    }

    var isRunning: Bool { job != nil }

    /// Bricht ab; eine angefangene Teildatei auf dem Mac ist sofort weg (auch beim Beenden der App).
    func cancel() { job?.cancel() }

    // MARK: - Hochladen

    /// Dateien vom Mac in einen Ordner auf dem Server (Ablagefläche, Terminal, Symbolleiste); fragt nach dem Zielordner.
    /// Ob gerade übertragen werden darf (verbunden, kein anderes Sheet), prüft der Aufrufer.
    func upload(_ urls: [URL]) {
        guard job == nil, let window = window(), let file = connection()?.transferSettings else { return }
        let files: [URL]
        do {
            files = try Self.regularFiles(urls)
        } catch {
            report(error.text, isError: true)
            return
        }
        let address: (user: String, host: String) = file.transferAddress
        Task {
            let request: TransferRequest? = await TransferPrompts.sheet(on: window) { finish in
                TransferRequestSheet(uploads: files.map(\.lastPathComponent), server: Self.server(address),
                                     needsUser: address.user.isEmpty, path: self.remoteFolder, user: self.askedUser, finish: finish)
            }
            guard let request else { return }
            remoteFolder = request.path.path
            if let user = request.user { askedUser = user }
            await performUpload(files, to: request.path, user: request.user)
        }
    }

    /// Ab hier ohne Sheet (Tests rufen das direkt auf).
    func performUpload(_ files: [URL], to folder: RemotePath, user: String?) async {
        let names: [String] = files.map(\.lastPathComponent)
        // im selben Zielordner überschriebe die zweite die erste, ohne dass der Server sie vorher kennt; ohne
        // Groß-/Kleinschreibung wie beim Ordnerinhalt (ein Mac als Server unterscheidet sie nicht)
        var seen: Set<String> = []
        if let twice = names.first(where: { !seen.insert($0.lowercased()).inserted }) {
            report("Nicht hochgeladen: Zwei Dateien heißen „\(SessionWarning.visible(twice))“ – bitte einzeln hochladen.", isError: true)
            return
        }
        guard let job = await begin(user: user) else { return }
        defer { end(job) }
        let environment: [String: String] = ProcessInfo.processInfo.environment
        let directory: String = job.directory.url.path
        func command(_ file: URL, _ withPassword: Bool) throws -> PscpCommand {
            try PscpCommand.upload(file.path, to: folder, host: job.host, sessionName: job.sessionName, puttyDirectory: directory,
                                   parentEnvironment: environment, passwordFromPipe: withPassword)
        }
        do {
            for file in files { _ = try command(file, false) }   // alle Namen prüfen, bevor etwas übertragen wird
            model.activity = "Zielordner prüfen …"
            let listing: (output: String, complete: Bool) = try await pscp(job, limit: Self.listingLimit) { withPassword in
                try PscpCommand.list(folder, host: job.host, sessionName: job.sessionName, puttyDirectory: directory,
                                     parentEnvironment: environment, passwordFromPipe: withPassword)
            }
            // unvollständig (riesiger Ordner): lieber für jede Datei fragen als still überschreiben
            let existing: [String] = listing.complete ? await PscpOutput.existing(names, in: listing.output) : names
            if job.cancelled { throw TransferError.cancelled }   // beim Auswerten eines großen Ordners abgebrochen
            if !existing.isEmpty, !(await prompts.replace(existing)) {
                report("Nicht hochgeladen.", isError: false)
                return
            }
            for (index, file) in files.enumerated() {
                let shown: String = "„\(SessionWarning.visible(names[index]))“"
                model.activity = files.count == 1 ? "\(shown) hochladen" : "\(shown) hochladen (\(index + 1) von \(files.count))"
                model.fraction = 0
                job.unfinishedUpload = names[index]
                try await pscp(job, progress: progress) { withPassword in try command(file, withPassword) }
                job.unfinishedUpload = nil
            }
            let what: String = names.count == 1 ? "„\(SessionWarning.visible(names[0]))“" : "\(names.count) Dateien"
            report("\(what) hochgeladen \(Self.place(folder)).", isError: false)
        } catch TransferError.cancelled {
            let unfinished: String? = job.unfinishedUpload.map(SessionWarning.visible)
            report(unfinished.map { "Abgebrochen. Auf dem Server liegt eine unvollständige „\($0)“." } ?? "Abgebrochen.", isError: false)
        } catch {
            report("Nicht hochgeladen: " + error.text, isError: true)
        }
    }

    // MARK: - Herunterladen

    /// Eine Datei vom Server; fragt nach dem Pfad und danach im Sichern-Dialog nach Ort und Namen auf dem Mac.
    func download() {
        guard job == nil, let window = window(), let file = connection()?.transferSettings else { return }
        let address: (user: String, host: String) = file.transferAddress
        Task {
            let request: TransferRequest? = await TransferPrompts.sheet(on: window) { finish in
                TransferRequestSheet(uploads: nil, server: Self.server(address), needsUser: address.user.isEmpty, path: "",
                                     user: self.askedUser, finish: finish)
            }
            // Den Namen bestimmt die App aus dem eingegebenen Pfad, nie der Server (RemotePath: ohne /, .., Steuerzeichen)
            guard let request, let name = request.path.localFileName else { return }
            if let user = request.user { askedUser = user }
            let panel: NSSavePanel = NSSavePanel()
            panel.nameFieldStringValue = name
            panel.directoryURL = downloadFolder ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            panel.message = "„\(SessionWarning.visible(name))“ von \(Self.server(address)) sichern"
            guard await panel.beginSheetModal(for: window) == .OK, let target = panel.url else { return }
            downloadFolder = target.deletingLastPathComponent()
            await performDownload(request.path, to: target, user: request.user)
        }
    }

    /// Ab hier ohne Dialoge (Tests rufen das direkt auf). Eine vorhandene Zieldatei hat der Sichern-Dialog bestätigt.
    func performDownload(_ remote: RemotePath, to target: URL, user: String?) async {
        guard let job = await begin(user: user) else { return }
        defer { end(job) }
        let part: URL = target.deletingLastPathComponent().appendingPathComponent(".\(AppIdentity.name)-\(UUID().uuidString).teil")
        let shown: String = "„\(SessionWarning.visible(target.lastPathComponent))“"
        let environment: [String: String] = ProcessInfo.processInfo.environment
        do {
            model.activity = "\(shown) herunterladen"
            job.partFile = part
            try await pscp(job, progress: progress) { withPassword in
                try PscpCommand.download(remote, to: part.path, host: job.host, sessionName: job.sessionName,
                                         puttyDirectory: job.directory.url.path, parentEnvironment: environment,
                                         passwordFromPipe: withPassword)
            }
            // pscp übernimmt die Rechte vom Server (auch „ausführbar“); wie bei einem Download aus Safari nur lesen/schreiben.
            // Erst dann ersetzt die neue Datei eine vorhandene (rename ist atomar im selben Ordner).
            guard chmod(part.path, 0o600) == 0, rename(part.path, target.path) == 0 else {
                throw TransferError.failed("Ablegen nicht möglich: \(String(cString: strerror(errno)))")
            }
            job.partFile = nil
            Self.markAsDownloaded(target)
            model.downloaded = target
            report("\(shown) geladen.", isError: false)
        } catch TransferError.cancelled {
            report("Abgebrochen – auf dem Mac ist nichts geändert.", isError: false)
        } catch {
            report("Nicht geladen: " + error.text, isError: true)
        }
    }

    // MARK: - pscp

    /// Kopie der Sitzung mit Benutzer schreiben (docs/M6-Machbarkeit.md 2); vorher fragen, wenn sie beim Verbinden etwas
    /// auf diesem Mac ausführt (S4, wie vor jedem Verbinden).
    private func begin(user askedUser: String?) async -> Job? {
        guard job == nil, let connection = connection(), var file = connection.transferSettings, file.connectionProtocol == .ssh else {
            report("Dateien lassen sich nur über SSH übertragen.", isError: true)
            return nil
        }
        do {
            let warnings: [SessionWarning] = try connection.warningsRequiringConfirmation(for: file)
            if !warnings.isEmpty, !(await prompts.dangers(warnings, connection.displayName)) { return nil }
        } catch {
            report("Die Sitzung ist nicht lesbar (\(error.text)).", isError: true)
            return nil
        }
        guard job == nil else { return nil }   // während der Rückfrage gestartet
        let address: (user: String, host: String) = file.transferAddress
        let user: String = address.user.isEmpty ? askedUser ?? "" : address.user
        guard !user.isEmpty else {
            report(InputError.empty(.user).message, isError: true)
            return nil
        }
        let sessionName: String = AppIdentity.quickSessionPrefix + UUID().uuidString
        do {
            if address.user.isEmpty {
                try file.setUserName(user)   // erfragt: dieselben Regeln wie im Editor (S3)
            } else {
                try file.setValue(user, forKey: "UserName")   // aus der Sitzung, wie plink ihn liest (auch aus „benutzer@“)
            }
            let directory: PuTTYDirectory = try connection.puttyDirectory()
            try directory.write(file, sessionName: sessionName)
            let started: Job = Job(sessionName: sessionName, host: address.host, user: user, directory: directory,
                                   storedPassword: connection.storedPasswordForTransfer(),
                                   mayAskPassword: file.passwordUnavailableReason == nil)
            job = started
            model.result = nil
            model.downloaded = nil
            revealInspector?()
            return started
        } catch {
            report(error.text, isError: true)
            return nil
        }
    }

    private func end(_ finished: Job) {
        finished.removePartFile()
        finished.directory.removeSession(named: finished.sessionName)
        if job === finished { job = nil }
        model.activity = nil
        model.fraction = nil
    }

    private func progress(_ percent: Int) {
        model.fraction = Double(percent) / 100
    }

    /// Startet pscp; verlangt der Server ein Passwort, fragt die App einmal danach und versucht es erneut.
    /// `complete`: Die Ausgabe passte in `limit` (sonst fehlt ihr Anfang).
    @discardableResult
    private func pscp(_ job: Job, limit: Int = outputLimit, progress: ((Int) -> Void)? = nil,
                      _ make: (Bool) throws -> PscpCommand) async throws -> (output: String, complete: Bool) {
        while true {
            if job.cancelled { throw TransferError.cancelled }
            let command: PscpCommand
            do {
                command = try make(job.secret != nil)
            } catch {
                throw TransferError.failed(error.text)
            }
            let result: (status: Int32, output: String, complete: Bool) = await run(command, job: job, limit: limit, progress: progress)
            if job.cancelled { throw TransferError.cancelled }
            if result.status == 0 { return (result.output, result.complete) }
            let failure: TransferFailure = PscpOutput.failure(in: result.output)
            let wantsLogin: Bool = failure == .passwordNeeded || failure == .passwordRejected
            guard wantsLogin, job.mayAskPassword, !job.askedForPassword else { throw TransferError.failed(Self.explain(failure, job)) }
            job.askedForPassword = true
            guard let typed = await prompts.password(Self.server((job.user, job.host)), failure == .passwordRejected) else {
                throw TransferError.cancelled
            }
            job.secret = Data(typed.utf8)
        }
    }

    /// Ein Lauf von pscp an einem eigenen PTY wie plink (`TerminalProcess`: Argumentliste, nur 0/1/2 und fd 3, S3/S8).
    private func run(_ command: PscpCommand, job: Job, limit: Int,
                     progress: ((Int) -> Void)?) async -> (status: Int32, output: String, complete: Bool) {
        let process: TerminalProcess = TerminalProcess()
        var tail: [UInt8] = []
        var complete: Bool = true
        process.onOutput = { bytes in
            tail.append(contentsOf: bytes)
            if tail.count > (complete ? limit : Self.outputLimit) {
                // zu viel: Dann zählt nur noch die Meldung am Ende – einmal kürzen statt je Block Megabytes verschieben
                tail.removeFirst(tail.count - Self.outputLimit)
                complete = false
            }
            if let progress, let percent = PscpOutput.percent(in: String(decoding: tail.suffix(256), as: UTF8.self)) {
                progress(percent)
            }
        }
        job.process = process
        defer { job.process = nil }
        return await withCheckedContinuation { continuation in
            process.onExit = { status in continuation.resume(returning: (status, String(decoding: tail, as: UTF8.self), complete)) }
            do {
                try process.start(executable: pscpPath, arguments: command.arguments, environment: command.environment,
                                  columns: 200, rows: 24, secret: job.secret)
            } catch {
                process.onExit = nil
                continuation.resume(returning: (-1, error.text, true))
            }
        }
    }

    private static func explain(_ failure: TransferFailure, _ job: Job) -> String {
        switch failure {
        case .passwordNeeded where !job.mayAskPassword:
            "Der Server verlangt ein Passwort. Mit Proxy oder fest vorgegebenen Hostschlüsseln gibt die App keines an pscp "
                + "weiter – bitte mit Schlüssel oder Agent anmelden."
        case .passwordNeeded:
            "Der Server fragt mehr als ein Passwort ab (z. B. einen zweiten Faktor) – das kann pscp hier nicht beantworten."
        default:
            failure.message
        }
    }

    // MARK: - Hilfen

    private func report(_ text: String, isError: Bool) {
        model.result = text
        model.resultIsError = isError
        AppLog.connection.info("Dateiübertragung beendet, Fehler: \(isError, privacy: .public)")
        NSAccessibility.post(element: window() as Any, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    /// Nur Dateien (ein Ordner bräuchte `pscp -r`, nicht vorgesehen); ein Verweis zählt als sein Ziel, pscp folgt ihm.
    private static func regularFiles(_ urls: [URL]) throws -> [URL] {
        guard !urls.isEmpty else { throw TransferError.failed("Keine Datei gewählt.") }
        for url in urls {
            let values: URLResourceValues? = try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isRegularFileKey])
            guard url.isFileURL, values?.isRegularFile == true else {
                throw TransferError.failed("„\(SessionWarning.visible(url.lastPathComponent))“ ist keine Datei – Ordner lassen sich nicht hochladen.")
            }
        }
        return urls
    }

    /// „benutzer@server“ für Sheets und Dialoge, sichtbar gemacht.
    private static func server(_ address: (user: String, host: String)) -> String {
        SessionWarning.visible(address.user.isEmpty ? address.host : "\(address.user)@\(address.host)")
    }

    private static func place(_ folder: RemotePath) -> String {
        folder.path.isEmpty ? "in den persönlichen Ordner" : "nach „\(SessionWarning.visible(folder.path))“"
    }

    /// Wie ein Download aus Safari: macOS prüft Programme daraus beim ersten Öffnen (Gatekeeper) – der Inhalt kommt vom
    /// Server. Gelingt das Markieren nicht, bleibt die Datei trotzdem (kein Datenverlust).
    private static func markAsDownloaded(_ url: URL) {
        var values: URLResourceValues = URLResourceValues()
        values.quarantineProperties = [kLSQuarantineTypeKey as String: kLSQuarantineTypeOtherDownload as String,
                                       kLSQuarantineAgentNameKey as String: AppIdentity.name]
        var marked: URL = url
        try? marked.setResourceValues(values)
    }

    fileprivate enum TransferError: Error {
        case cancelled
        case failed(String)

        var message: String {
            switch self {
            case .cancelled: "Abgebrochen."
            case .failed(let text): text
            }
        }
    }

    /// Eine laufende Übertragung: vorübergehende Sitzung, Anmeldung, laufendes pscp, Teildatei.
    private final class Job {
        let sessionName: String
        let host: String
        let user: String
        let directory: PuTTYDirectory
        /// Aus dem Schlüsselbund oder einmal abgefragt; nur für diese Übertragung, geht über fd 3 (S1).
        var secret: Data?
        let mayAskPassword: Bool
        var askedForPassword: Bool = false
        private(set) var cancelled: Bool = false
        var process: TerminalProcess?
        /// Wird gerade hochgeladen (nach einem Abbruch liegt sie unvollständig auf dem Server).
        var unfinishedUpload: String?
        /// Teildatei beim Herunterladen.
        var partFile: URL?

        init(sessionName: String, host: String, user: String, directory: PuTTYDirectory, storedPassword: Data?,
             mayAskPassword: Bool) {
            self.sessionName = sessionName
            self.host = host
            self.user = user
            self.directory = directory
            secret = storedPassword
            self.mayAskPassword = mayAskPassword
        }

        func cancel() {
            cancelled = true
            process?.hangUp()
            removePartFile()   // pscp darf weiterschreiben: die Datei ist dann schon ohne Namen
        }

        func removePartFile() {
            if let partFile { unlink(partFile.path) }
            partFile = nil
        }
    }
}

private extension Error {
    var text: String {
        switch self {
        case let error as InputError: error.message
        case let error as TerminalProcess.Failure: error.message
        case let error as FileTransferController.TransferError: error.message
        default: localizedDescription
        }
    }
}
