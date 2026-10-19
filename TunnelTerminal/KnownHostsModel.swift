import Observation
import TunnelTerminalCore

/// Liste „Bekannte Hostschlüssel“ (Plan M3): liest `sshhostkeys` im PuTTY-Ordner der App und entfernt einzelne
/// Einträge, z. B. nach einer Neuinstallation des Servers. Danach fragt plink beim nächsten Verbinden wieder (S5).
@Observable
final class KnownHostsModel {
    let directory: PuTTYDirectory
    private(set) var entries: [KnownHostKey] = []
    var selection: Set<String> = []
    var failure: String?
    var isConfirmingRemoval: Bool = false

    init(directory: PuTTYDirectory) {
        self.directory = directory
    }

    /// Neu lesen (beim Öffnen des Fensters und wenn es nach vorne kommt: plink kann inzwischen Schlüssel gespeichert haben).
    func reload() {
        do {
            entries = try directory.knownHostKeys().entries
            failure = nil
        } catch {
            entries = []
            failure = "Die Datei mit den bekannten Hostschlüsseln ist nicht lesbar."
        }
        selection = selection.filter { id in entries.contains { $0.id == id } }
    }

    func requestRemoval() {
        if !selection.isEmpty { isConfirmingRemoval = true }
    }

    func removeSelection() {
        do {
            try directory.removeKnownHostKeys(selection)
            selection = []
        } catch {
            failure = "Entfernen nicht möglich: \(error.localizedDescription)"
        }
        reload()
    }
}
