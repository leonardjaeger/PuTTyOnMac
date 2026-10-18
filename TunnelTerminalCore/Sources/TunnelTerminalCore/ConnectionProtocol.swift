/// Protokolle der Schnellverbindung. Der Rohwert ist PuTTYs `Protocol`-Wert (docs/M1-Recherche.md 2.1).
public enum ConnectionProtocol: String, CaseIterable, Identifiable, Sendable {
    case ssh
    case telnet
    case raw

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ssh: "SSH"
        case .telnet: "Telnet"
        case .raw: "Raw"
        }
    }

    /// Raw hat in PuTTY keinen Standardport.
    public var defaultPort: Int? {
        switch self {
        case .ssh: 22
        case .telnet: 23
        case .raw: nil
        }
    }
}
