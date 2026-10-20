import AppKit

/// Hilfe › Tastenkürzel (Plan M7): liest die Menüleiste beim Öffnen (die Übersicht veraltet nie) und ergänzt die Tasten
/// ohne Menüeintrag. Zusatztasten in der Reihenfolge ⌃ ⌥ ⇧ ⌘ (Richtlinien 3.5 Regel 4).
enum ShortcutOverview {
    struct Entry: Identifiable, Hashable {
        let group: String
        let title: String
        let keys: String
        var id: String { "\(group)|\(title)|\(keys)" }
    }

    private static let groupWithoutMenu: String = "Ohne Menüeintrag"

    /// Tasten, die kein Menü zeigt (Schnellverbindung, Seitenleiste, Hinweisleiste beim Einfügen, F1–F4).
    static let withoutMenu: [Entry] = [
        Entry(group: groupWithoutMenu, title: "Schnellverbindung: verbinden", keys: "↩"),
        Entry(group: groupWithoutMenu, title: "Sitzung in der Seitenleiste verbinden", keys: "Doppelklick"),
        Entry(group: groupWithoutMenu, title: "Mehrzeiliges Einfügen: trotzdem einfügen", keys: "⌘↩"),
        Entry(group: groupWithoutMenu, title: "Mehrzeiliges Einfügen: abbrechen", keys: "⎋"),
        Entry(group: groupWithoutMenu, title: "Leeren, Alles kopieren, Verbindung duplizieren, Titel ändern "
              + "(wenn unter Einstellungen › Allgemein eingeschaltet)", keys: "F1 F2 F3 F4")
    ]

    /// Alle Menüeinträge mit Kürzel, nach Menü gruppiert; Untermenüs als „Suchen › Weitersuchen“.
    static func entries(from menu: NSMenu?) -> [Entry] {
        guard let menu else { return [] }
        var entries: [Entry] = []
        func collect(_ submenu: NSMenu, group: String, prefix: String) {
            for item in submenu.items where !item.isSeparatorItem && !item.isHidden {
                let title: String = prefix.isEmpty ? item.title : "\(prefix) › \(item.title)"
                if let child = item.submenu {
                    collect(child, group: group, prefix: title)
                } else if !item.keyEquivalent.isEmpty {
                    entries.append(Entry(group: group, title: title,
                                         keys: label(key: item.keyEquivalent, modifiers: item.keyEquivalentModifierMask)))
                }
            }
        }
        for top in menu.items {
            if let submenu = top.submenu { collect(submenu, group: top.title, prefix: "") }
        }
        return entries
    }

    /// Auch für Einträge, die macOS selbst in die Menüleiste setzt (Tab-Wechsel mit ⇥, „Bewegen & Größe ändern“ mit
    /// fn und Pfeiltasten): ein Großbuchstabe als Taste bedeutet ⇧ (wie AppKit).
    static func label(key: String, modifiers: NSEvent.ModifierFlags) -> String {
        var text: String = modifiers.contains(.function) ? "fn" : ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) || (key != key.lowercased()) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + keyName(key)
    }

    private static func keyName(_ key: String) -> String {
        guard key.unicodeScalars.count == 1, let scalar = key.unicodeScalars.first else { return key.uppercased() }
        switch scalar.value {
        case 0x08, 0x7F: return "⌫"
        case 0x0D, 0x03: return "↩"
        case 0x1B: return "⎋"
        case 0x09: return "⇥"
        case 0x19: return "⇤"
        case 0x20: return "Leertaste"
        case 0xF700: return "↑"
        case 0xF701: return "↓"
        case 0xF702: return "←"
        case 0xF703: return "→"
        case 0xF704...0xF726: return "F\(scalar.value - 0xF704 + 1)"   // NSF1FunctionKey … NSF35FunctionKey
        case 0xF728: return "⌦"
        case 0xF729: return "↖"
        case 0xF72B: return "↘"
        case 0xF72C: return "⇞"
        case 0xF72D: return "⇟"
        default: return key.uppercased()
        }
    }
}
