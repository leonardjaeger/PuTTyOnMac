import Foundation
import TunnelTerminalCore

/// Eine Verbindung eines Tabs: schreibt die vorübergehende Sitzung in den PuTTY-Ordner, startet plink mit
/// `-load` (S3) und entfernt die Sitzung wieder, sobald plink beendet ist.
final class Connection {
    let endpoint: Endpoint
    let connectionProtocol: ConnectionProtocol

    var onOutput: ((ArraySlice<UInt8>) -> Void)? {
        get { process.onOutput }
        set { process.onOutput = newValue }
    }
    /// Text für den Hinweis bei Verbindungsende.
    var onEnd: ((String) -> Void)?

    var isRunning: Bool { process.isRunning }

    private let session: SessionFile
    private let sessionName: String = AppIdentity.quickSessionPrefix + UUID().uuidString
    private let process: TerminalProcess = TerminalProcess()
    private var hungUpByUser: Bool = false
    private let puttyDirectory: @MainActor () throws -> PuTTYDirectory

    /// `puttyDirectory` nur für Tests ändern (eigener Ordner statt Application Support, RL 3.9).
    init(endpoint: Endpoint, connectionProtocol: ConnectionProtocol,
         puttyDirectory: @escaping @MainActor () throws -> PuTTYDirectory = AppIdentity.puttyDirectory) throws(InputError) {
        self.endpoint = endpoint
        self.connectionProtocol = connectionProtocol
        self.puttyDirectory = puttyDirectory
        session = try SessionFile.quickConnect(to: endpoint, using: connectionProtocol)
    }

    /// Startet plink. Fehler kommen als lesbarer Text zurück.
    func start(columns: Int, rows: Int) throws(TerminalProcess.Failure) {
        let directory: PuTTYDirectory
        let command: PlinkCommand
        do {
            directory = try puttyDirectory()
            try directory.write(session, sessionName: sessionName)
            command = try PlinkCommand(sessionName: sessionName, puttyDirectory: directory.url.path,
                                       parentEnvironment: ProcessInfo.processInfo.environment)
        } catch {
            throw TerminalProcess.Failure(message: "Sitzung konnte nicht vorbereitet werden: \(error.localizedDescription)")
        }
        let name: String = sessionName
        process.onExit = { [weak self] status in
            directory.removeSession(named: name)
            AppLog.connection.info("Verbindung beendet, Status \(status, privacy: .public)")
            guard let self else { return }
            // Selbst getrennt: kein „Signal 1“ anzeigen
            self.onEnd?(self.hungUpByUser ? "Verbindung getrennt." : TerminalProcess.describe(status: status))
        }
        do {
            try process.start(executable: AppIdentity.plinkPath, arguments: command.arguments,
                              environment: command.environment, columns: columns, rows: rows)
        } catch {
            directory.removeSession(named: name)
            process.onExit = nil
            throw error
        }
        AppLog.connection.info("Verbindung gestartet zu \(self.endpoint.host, privacy: .private(mask: .hash)), Protokoll \(self.connectionProtocol.rawValue, privacy: .public)")
    }

    func send(_ data: ArraySlice<UInt8>) { process.send(data) }
    func resize(columns: Int, rows: Int) { process.resize(columns: columns, rows: rows) }
    func hangUp() {
        hungUpByUser = process.isRunning
        process.hangUp()
    }
}
