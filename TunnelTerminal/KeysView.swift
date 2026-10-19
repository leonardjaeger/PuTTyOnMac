import SwiftUI
import TunnelTerminalCore

/// Fenster „Schlüssel“ (Plan M3, Oberfläche 3.1: erreichbar unten in der Seitenleiste und über Fenster › Schlüssel).
struct KeysView: View {
    @Bindable var model: KeysModel

    var body: some View {
        Form {
            Section("Neuer Schlüssel") {
                Picker("Typ", selection: $model.kind) {
                    ForEach(KeyKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                TextField("Kommentar", text: $model.comment, prompt: Text("z. B. Name dieses Macs"))
                SecureField("Passphrase", text: $model.passphrase)
                SecureField("Wiederholen", text: $model.repeatedPassphrase)
                if !model.passphrasesMatch {
                    Label("Die Passphrasen stimmen nicht überein.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                } else if model.passphrase.isEmpty {
                    Text("Ohne Passphrase kann jeder, der die Datei bekommt, den Schlüssel benutzen.")
                        .foregroundStyle(.secondary)
                }
                Button("Erzeugen und sichern …", action: model.generate)
                    .disabled(!model.passphrasesMatch || model.isWorking)
            }
            Section {
                if let key = model.key {
                    LoadedKeyDetails(model: model, key: key)
                } else {
                    Text("Noch kein Schlüssel geöffnet.")
                        .foregroundStyle(.secondary)
                }
                Button("Schlüsseldatei öffnen …", action: model.open)
                    .disabled(model.isWorking)
            } header: {
                Text("Schlüssel")
            }
            Section("Mit dem macOS-Agenten") {
                Text("Ohne Schlüsseldatei in der Sitzung fragt plink zuerst den Agenten von macOS. Einen OpenSSH-Schlüssel (nicht .ppk – vorher umwandeln) legst du dort einmal im Terminal ab; die Passphrase merkt sich der Schlüsselbund. Nach einem Neustart lädt ihn der zweite Befehl wieder.")
                    .foregroundStyle(.secondary)
                CommandText(command: model.agentCommand ?? "ssh-add --apple-use-keychain ~/.ssh/id_ed25519")
                CommandText(command: "ssh-add --apple-load-keychain")
            }
            if model.isWorking || model.message != nil {
                Section {
                    if model.isWorking {
                        ProgressView("puttygen arbeitet …")
                    } else if let message = model.message {
                        Text(message)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .autocorrectionDisabled()
        .frame(minWidth: 520, idealWidth: 580, minHeight: 520, idealHeight: 700)
        .sheet(item: $model.passphraseRequest) { request in
            PassphrasePrompt(request: request, answer: { model.answer(request, passphrase: $0) },
                             cancel: { model.passphraseRequest = nil })
        }
    }
}
