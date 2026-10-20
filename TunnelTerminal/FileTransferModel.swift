import Foundation
import Observation

/// Was der Inspektor-Abschnitt „Dateien“ über die Übertragungen dieses Tabs zeigt (Plan 3.1, M6).
@Observable
final class FileTransferModel {
    /// Läuft gerade, z. B. „„bericht.pdf“ hochladen (2 von 3)“; `nil`, wenn nichts läuft.
    var activity: String?
    /// Anteil 0…1 laut pscp; `nil`, solange pscp sich anmeldet oder den Zielordner prüft.
    var fraction: Double?
    /// Ergebnis der letzten Übertragung.
    var result: String?
    var resultIsError: Bool = false
    /// Zuletzt geladene Datei („Im Finder zeigen“).
    var downloaded: URL?
    /// Befehle des Abschnitts, direkt an den Tab (nicht über die Responder-Kette: der Inspektor eines Tabs im Hintergrund
    /// meint seinen eigenen Tab).
    @ObservationIgnored var upload: (([URL]) -> Void)?
    @ObservationIgnored var chooseFiles: (() -> Void)?
    @ObservationIgnored var download: (() -> Void)?
    @ObservationIgnored var cancel: (() -> Void)?
}
