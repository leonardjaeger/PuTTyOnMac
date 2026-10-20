import SwiftUI

/// Inhalt des Fensters „Tastenkürzel“ (Hilfe-Menü, Plan M7).
struct ShortcutsView: View {
    let entries: [ShortcutOverview.Entry]

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(groups, id: \.name) { group in
                    Section(group.name) {
                        ForEach(group.entries) { entry in
                            LabeledContent(entry.title) {
                                Text(entry.keys)
                                    .monospaced()
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            Divider()
            Text("Zusatztasten: ⌃ Control, ⌥ Option, ⇧ Umschalt, ⌘ Befehl. Die Menübefehle liest die Übersicht aus der "
                 + "Menüleiste, Tasten ohne Menüeintrag stehen in der letzten Gruppe.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(minWidth: 460, minHeight: 360)
    }

    /// Gruppen in der Reihenfolge der Menüleiste.
    private var groups: [(name: String, entries: [ShortcutOverview.Entry])] {
        var order: [String] = []
        var byGroup: [String: [ShortcutOverview.Entry]] = [:]
        for entry in entries {
            if byGroup[entry.group] == nil { order.append(entry.group) }
            byGroup[entry.group, default: []].append(entry)
        }
        return order.map { ($0, byGroup[$0] ?? []) }
    }
}
