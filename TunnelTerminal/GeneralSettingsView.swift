import SwiftUI

/// Einstellungen › Allgemein (Plan M4; weitere Reiter in M7): PuTTY-Gewohnheiten, aus im Standard.
struct GeneralSettingsView: View {
    @AppStorage(AppSettings.copyOnSelect) private var copyOnSelect: Bool = false
    @AppStorage(AppSettings.pasteOnRightClick) private var pasteOnRightClick: Bool = false
    @AppStorage(AppSettings.functionKeys) private var functionKeys: Bool = false

    var body: some View {
        Form {
            Section("Maus wie in PuTTY") {
                Toggle("Markierten Text sofort kopieren", isOn: $copyOnSelect)
                Toggle("Rechtsklick fügt ein", isOn: $pasteOnRightClick)
            }
            Section {
                Toggle("F1–F4 als Befehle", isOn: $functionKeys)
            } header: {
                Text("Tastatur")
            } footer: {
                Text("F1 leert Bildschirm und Verlauf, F2 kopiert alles, F3 dupliziert die Verbindung, F4 ändert den Titel. "
                     + "Programme auf dem Server (z. B. mc, htop) bekommen F1–F4 dann nicht mehr.")
                    .foregroundStyle(.secondary)
            }
            Section {
            } footer: {
                Text("Änderungen gelten sofort.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}
