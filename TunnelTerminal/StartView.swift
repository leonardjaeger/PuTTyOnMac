import SwiftUI

/// Inhalt eines Tabs, der noch nicht verbunden hat (Plan 3.1): Hinweis, wie man verbindet; ohne Sitzungen die Wege
/// zum Anlegen und Importieren.
struct StartView: View {
    let model: SessionsModel

    var body: some View {
        if model.library.names.isEmpty {
            ContentUnavailableView {
                Label("Noch keine Sitzungen", systemImage: "server.rack")
            } description: {
                Text("Gib links oben eine Adresse ein, lege eine Sitzung an oder importiere Sitzungen aus PuTTY.")
            } actions: {
                Button("Neue Sitzung", action: model.newSession)
                Menu("Importieren") {
                    Button("Registrierungsdatei (.reg) aus Windows-PuTTY …") { model.onImport(.registry) }
                    Button("PuTTY-Ordner aus macOS/Linux …") { model.onImport(.folder) }
                }
                .fixedSize()
            }
        } else {
            ContentUnavailableView("Nicht verbunden", systemImage: "terminal",
                                   description: Text("Doppelklick auf eine Sitzung links oder oben links eine Adresse eingeben (⇧⌘K)."))
        }
    }
}
