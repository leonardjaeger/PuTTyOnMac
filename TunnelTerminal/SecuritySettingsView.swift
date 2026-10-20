import SwiftUI

/// Einstellungen › Sicherheit (Plan M7): Wünsche des Servers und Links aus anderen Apps nur strenger stellen als im
/// Standard (Rückfrage); die festen Schutzregeln stehen zur Information darunter.
struct SecuritySettingsView: View {
    @AppStorage(AppSettings.blockServerClipboard) private var blockServerClipboard: Bool = false
    @AppStorage(AppSettings.blockTerminalLinks) private var blockTerminalLinks: Bool = false
    @AppStorage(AppSettings.blockAppLinks) private var blockAppLinks: Bool = false

    var body: some View {
        Form {
            Section {
                Picker("Text in die Zwischenablage legen", selection: $blockServerClipboard) {
                    Text("Jedes Mal fragen").tag(false)
                    Text("Immer ablehnen").tag(true)
                }
                Picker("Links aus dem Terminal öffnen", selection: $blockTerminalLinks) {
                    Text("Jedes Mal fragen").tag(false)
                    Text("Nie öffnen").tag(true)
                }
            } header: {
                Text("Wünsche des Servers")
            } footer: {
                Text("Programme auf dem Server können Text in die Zwischenablage legen (OSC 52) oder Links anbieten. "
                     + "Die Zwischenablage lesen dürfen sie nie.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker("ssh://- und telnet://-Links", selection: $blockAppLinks) {
                    Text("Nach Bestätigung öffnen").tag(false)
                    Text("Nie öffnen").tag(true)
                }
            } header: {
                Text("Links aus anderen Apps")
            } footer: {
                Text("Übernommen werden nur Benutzer, Server und Port, nie ein Passwort oder weitere Angaben. "
                     + "Welche App solche Links öffnet, steht unter „Erweitert“.")
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Mehrzeiliges Einfügen", value: "Immer mit Rückfrage")
                LabeledContent("Hostschlüssel", value: "Nie ohne Bestätigung")
                LabeledContent("Passwörter", value: "Nur im Schlüsselbund dieses Macs")
            } header: {
                Text("Immer eingeschaltet")
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
