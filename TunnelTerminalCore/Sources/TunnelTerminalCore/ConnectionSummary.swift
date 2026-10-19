import Foundation

/// Was der Inspektor-Abschnitt „Verbindung“ über eine Sitzung zeigt (Plan 3.1). Gilt für gespeicherte Sitzungen und
/// Schnellverbindungen (beide sind eine `SessionFile`). Alle Texte aus der Datei kommen über `visible` (S14/S4).
public struct ConnectionSummary: Equatable, Sendable {
    /// „server:port“, IPv6 in Klammern.
    public let server: String
    /// `nil`: plink fragt beim Verbinden.
    public let user: String?
    public let protocolTitle: String
    public let authentication: String

    public init(file: SessionFile) {
        let host: String = file.hostName
        let shownHost: String = host.contains(":") ? "[\(host)]" : host
        server = host.isEmpty ? "–" : SessionWarning.visible("\(shownHost):\(file.portNumber)")
        user = file.userName.isEmpty ? nil : SessionWarning.visible(file.userName)
        let rawProtocol: String = file.value(forKey: "Protocol") ?? "ssh"
        protocolTitle = file.connectionProtocol?.title ?? "Anderes (\(SessionWarning.visible(rawProtocol)))"
        switch file.connectionProtocol {
        case .ssh:
            let keyFile: String = file.value(forKey: "PublicKeyFile") ?? ""
            if !keyFile.isEmpty {
                authentication = "Schlüsseldatei „\(SessionWarning.visible(URL(fileURLWithPath: keyFile).lastPathComponent))“"
            } else if (file.integer(forKey: "TryAgent") ?? 1) != 0 {   // PuTTY probiert den Agenten standardmäßig
                authentication = "Agent, sonst Passwort"
            } else {
                authentication = "Passwort"
            }
        case .telnet: authentication = "Im Terminal (Telnet)"
        case .raw, nil: authentication = "Keine"
        }
    }
}
