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
    /// SSH: Abschnitt „Hostschlüssel“ zeigen (M3); die bekannten Schlüssel für Server und Port der Verbindung.
    var showsHostKeys: Bool = false
    var hostKeys: [KnownHostKey] = []
    /// Die Sitzung hat ein Passwort im Schlüsselbund (M3).
    var hasStoredPassword: Bool = false

    var statusText: String {
        isRunning ? "Verbunden" : (endMessage ?? "Nicht verbunden")
    }
}
