import SwiftUI
import TunnelTerminalCore

/// Angaben zum geöffneten Schlüssel im Fenster „Schlüssel“: Datei, Fingerabdruck, öffentlicher Teil, Umwandeln und
/// die Anleitung zum Übertragen auf den Server.
struct LoadedKeyDetails: View {
    let model: KeysModel
    let key: KeysModel.LoadedKey

    var body: some View {
        LabeledContent("Datei") {
            Text(key.url.lastPathComponent)
                .monospaced()
                .help(key.url.path)
        }
        LabeledContent("Fingerabdruck") {
            Text(key.fingerprint)
                .monospaced()
                .textSelection(.enabled)
        }
        LabeledContent("Öffentlicher Schlüssel") {
            Text(key.publicKey)
                .monospaced()
                .lineLimit(3)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        HStack {
            Button("Öffentlichen Schlüssel kopieren", systemImage: "doc.on.doc", action: model.copyPublicKey)
            Button("Fingerabdruck kopieren", action: model.copyFingerprint)
            Spacer()
            Menu("Umwandeln") {
                Button("Als PuTTY-Schlüssel (.ppk) sichern …") { model.convert(to: .putty) }
                Button("Als OpenSSH-Schlüssel sichern …") { model.convert(to: .openSSH) }
            }
            .fixedSize()
        }
        .disabled(model.isWorking)
        if let command = model.installCommand {
            VStack(alignment: .leading, spacing: 6) {
                Text("Auf den Server übertragen: Diesen Befehl auf dem Server im Terminal ausführen (einmal mit Passwort anmelden), dann in der Sitzung die .ppk-Datei als Schlüssel wählen.")
                    .foregroundStyle(.secondary)
                CommandText(command: command)
                Button("Befehl kopieren", systemImage: "doc.on.doc", action: model.copyInstallCommand)
            }
        }
    }
}
