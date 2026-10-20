import Foundation

/// Was der Inspektor-Abschnitt „Verbindung“ über eine Sitzung zeigt (Plan 3.1). Gilt für gespeicherte Sitzungen und
/// Schnellverbindungen (beide sind eine `SessionFile`). Alle Texte aus der Datei kommen über `visible` (S14/S4).
public struct ConnectionSummary: Equatable, Sendable {
    /// „server:port“, IPv6 in Klammern.
    public let server: String
    /// `nil`: plink fragt beim Verbinden.
    public let user: String?
    /// Zeile „Benutzer“ nur, wo es einen gibt (nicht bei Raw und Seriell).
    public let showsUser: Bool
    public let protocolTitle: String
    public let authentication: String
    /// Ohne Schlüsseldatei endet die Anmeldung beim Passwort (Agent vorher oder nicht): dort setzt ein gespeichertes
    /// Passwort an (M3).
    public let endsWithPassword: Bool
    /// Inspektor-Abschnitt „Tunnel“ (M5): Weiterleitungen wirken nur bei SSH.
    public let showsTunnels: Bool
    /// Proxy bzw. Jump-Host in Worten (M5); `nil` ohne Proxy und bei Seriell.
    public let proxy: String?
    public let portForwardings: [PortForwarding]

    public init(file: SessionFile) {
        let host: String = file.hostName
        let shownHost: String = host.contains(":") ? "[\(host)]" : host
        if file.connectionProtocol == .serial {
            server = file.serialLine.isEmpty ? "–" : SessionWarning.visible("\(file.serialLine), \(file.serialSpeed) Baud")
        } else {
            server = host.isEmpty ? "–" : SessionWarning.visible("\(shownHost):\(file.portNumber)")
        }
        user = file.userName.isEmpty || file.connectionProtocol == .serial ? nil : SessionWarning.visible(file.userName)
        showsUser = file.connectionProtocol != .raw && file.connectionProtocol != .serial
        showsTunnels = file.connectionProtocol == .ssh
        proxy = file.connectionProtocol == .serial ? nil : file.proxyDescription.map(SessionWarning.visible)
        portForwardings = showsTunnels ? file.portForwardings : []
        let rawProtocol: String = file.value(forKey: "Protocol") ?? "ssh"
        protocolTitle = file.connectionProtocol?.title ?? "Anderes (\(SessionWarning.visible(rawProtocol)))"
        endsWithPassword = file.connectionProtocol == .ssh && (file.value(forKey: "PublicKeyFile") ?? "").isEmpty
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
        case .raw, .serial, nil: authentication = "Keine"
        }
    }
}
