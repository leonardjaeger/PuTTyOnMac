import Observation
import TunnelTerminalCore

/// Schnellverbindung oben in der Seitenleiste (Plan M1, seit M2 in Gerüst B): Adresse „benutzer@server:port“ und
/// Protokoll. Je Fenster bzw. Tab eine.
@Observable
final class QuickConnect {
    var address: String
    var connectionProtocol: ConnectionProtocol
    var errorMessage: String?
    /// Zählt ⇧⌘K und neue Tabs: Die Seitenleiste setzt dann den Fokus ins Feld.
    private(set) var focusRequests: Int = 0

    /// Vom Fenster-Controller gesetzt: startet die Verbindung, liefert eine Fehlermeldung oder `nil`.
    @ObservationIgnored var connect: (String, ConnectionProtocol) -> String? = { _, _ in nil }

    init(address: String = "", connectionProtocol: ConnectionProtocol = .ssh) {
        self.address = address
        self.connectionProtocol = connectionProtocol
    }

    func submit() {
        guard !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        errorMessage = connect(address, connectionProtocol)
        if errorMessage == nil { address = "" }
    }

    func requestFocus() { focusRequests += 1 }
}
