import Observation
import TunnelTerminalCore

/// Was der Inspektor über die Verbindung dieses Tabs zeigt (Plan 3.1, Abschnitt „Verbindung“).
@Observable
final class ConnectionInfo {
    /// `nil`, solange der Tab noch nichts verbunden hat.
    var summary: ConnectionSummary?
    var isRunning: Bool = false
    /// Grund für das Ende der letzten Verbindung (wie im Hinweis über dem Terminal).
    var endMessage: String?

    var statusText: String {
        isRunning ? "Verbunden" : (endMessage ?? "Nicht verbunden")
    }
}
