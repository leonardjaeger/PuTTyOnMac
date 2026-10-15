import OSLog

/// Protokoll der App (S9): Server, Benutzer und Pfade nur mit `.private(mask: .hash)`,
/// öffentlich nur Zahlen und feste Texte. Jeder Aufruf steht in einer Zeile (Grundsatz-Test).
enum AppLog {
    static let connection: Logger = Logger(subsystem: AppIdentity.logSubsystem, category: "connection")
    static let app: Logger = Logger(subsystem: AppIdentity.logSubsystem, category: "app")
}
