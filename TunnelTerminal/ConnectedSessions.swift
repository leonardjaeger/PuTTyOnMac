import Observation

/// Gespeicherte Sitzungen mit laufender Verbindung, für den Status in der Seitenleiste (Plan 3.1). Gilt für alle
/// Fenster; eine Sitzung kann in mehreren Tabs laufen.
// shortcut: zählt nach Namen – nach Umbenennen oder Löschen einer verbundenen Sitzung stimmt der Punkt bis zum
// Verbindungsende nicht; bei Bedarf mit einer festen Kennung je Sitzung zählen (frühestens M7).
@Observable
final class ConnectedSessions {
    private var counts: [String: Int] = [:]

    func contains(_ name: String) -> Bool { (counts[name] ?? 0) > 0 }

    func started(_ name: String) { counts[name, default: 0] += 1 }

    func ended(_ name: String) {
        guard let count = counts[name] else { return }
        counts[name] = count > 1 ? count - 1 : nil
    }
}
