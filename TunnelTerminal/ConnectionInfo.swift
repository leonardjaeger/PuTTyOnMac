import Foundation
import Observation
import TunnelTerminalCore

/// Was Inspektor und Statuszeile über die Verbindung dieses Tabs zeigen (Plan 3.1).
@Observable
final class ConnectionInfo {
    /// `nil`, solange der Tab noch nichts verbunden hat.
    var summary: ConnectionSummary?
    var isRunning: Bool = false
    /// plink läuft, aber noch ist nichts angekommen (Verbindungsaufbau, M3-Notiz für M4).
    var isConnecting: Bool = false
    /// Grund für das Ende der letzten Verbindung (wie im Hinweis über dem Terminal).
    var endMessage: String?
    /// SSH: Abschnitt „Hostschlüssel“ zeigen (M3); die bekannten Schlüssel für Server und Port der Verbindung.
    var showsHostKeys: Bool = false
    var hostKeys: [KnownHostKey] = []
    /// Die Sitzung hat ein Passwort im Schlüsselbund (M3).
    var hasStoredPassword: Bool = false
    /// Profil dieses Tabs (M4); im Inspektor umschaltbar, gilt dann nur für den Tab.
    var profileID: UUID = TerminalProfile.standardID
    @ObservationIgnored var selectProfile: ((UUID) -> Void)?
    /// Terminalgröße für die Statuszeile.
    var columns: Int?
    var rows: Int?
    /// Die App schreibt ein Sitzungsprotokoll (M4).
    var isLogging: Bool = false

    var statusText: String {
        isRunning ? (isConnecting ? "Verbinde …" : "Verbunden") : (endMessage ?? "Nicht verbunden")
    }

    /// Kurzform für die Statuszeile (der Grund steht im Hinweis über dem Terminal).
    var shortStatus: String {
        isRunning ? statusText : (summary == nil ? "Nicht verbunden" : "Getrennt")
    }
}
