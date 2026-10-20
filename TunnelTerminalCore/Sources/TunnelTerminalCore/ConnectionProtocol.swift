/// Verbindungsarten der App (Schnellverbindung ohne Seriell). Der Rohwert ist PuTTYs `Protocol`-Wert (docs/M1-Recherche.md 2.1).
public enum ConnectionProtocol: String, CaseIterable, Identifiable, Sendable {
    case ssh
    case telnet
    case raw
    case serial

    public var id: String { rawValue }

    /// Seriell nur in gespeicherten Sitzungen: Die Schnellverbindung nimmt „benutzer@server:port“.
    public static let quickConnectCases: [ConnectionProtocol] = [.ssh, .telnet, .raw]

    public var title: String {
        switch self {
        case .ssh: "SSH"
        case .telnet: "Telnet"
        case .raw: "Raw"
        case .serial: "Seriell"
        }
    }

    /// Raw hat in PuTTY keinen Standardport.
    public var defaultPort: Int? {
        switch self {
        case .ssh: 22
        case .telnet: 23
        case .raw, .serial: nil
        }
    }
}
