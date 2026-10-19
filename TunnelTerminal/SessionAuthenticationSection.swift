import SwiftUI
import TunnelTerminalCore
import UniformTypeIdentifiers

/// Abschnitt „Anmeldung“ im Sitzungs-Editor (Plan M3): Schlüsseldatei (.ppk) und freiwillig ein Passwort im
/// Schlüsselbund. Ohne beides probiert plink den macOS-Agenten und fragt sonst im Terminal.
struct SessionAuthenticationSection: View {
    let file: SessionFile
    let sessionName: String
    let passwords: PasswordStore?
    /// Setzt `PublicKeyFile` (leer: keine Schlüsseldatei) über den Editor, der speichert und Fehler zeigt.
    let setKeyFile: (String) -> Void

    @State private var hasPassword: Bool = false
    @State private var isChoosingKey: Bool = false
    @State private var isSavingPassword: Bool = false
    @State private var keyProblem: String?

    var body: some View {
        Section {
            LabeledContent("Schlüsseldatei") {
                if file.publicKeyFile.isEmpty {
                    Text("Keine (Agent, sonst Passwort)")
                        .foregroundStyle(.secondary)
                } else {
                    Text(SessionWarning.visible(URL(fileURLWithPath: file.publicKeyFile).lastPathComponent))
                        .monospaced()
                        .help(SessionWarning.visible(file.publicKeyFile))
                }
            }
            HStack {
                Button("Wählen …") { isChoosingKey = true }
                if !file.publicKeyFile.isEmpty {
                    Button("Keine Schlüsseldatei") { setKeyFile("") }
                }
            }
            if let keyProblem {
                Label(keyProblem, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            if passwords != nil {
                LabeledContent("Passwort") {
                    Text(hasPassword ? "Im Schlüsselbund gespeichert" : "Nicht gespeichert – plink fragt beim Verbinden")
                        .foregroundStyle(hasPassword ? .primary : .secondary)
                }
                if let reason = file.passwordUnavailableReason {
                    Text(reason)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Button(hasPassword ? "Passwort ändern …" : "Im Schlüsselbund sichern …") { isSavingPassword = true }
                        if hasPassword {
                            Button("Aus dem Schlüsselbund löschen", role: .destructive, action: deletePassword)
                        }
                    }
                }
                Text(hasPassword ? Self.storedNote : "Nur auf diesem Mac, nur für diesen Benutzer und Server. Mit Schlüssel geht es sicherer.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Anmeldung")
        }
        .fileImporter(isPresented: $isChoosingKey, allowedContentTypes: [.data], onCompletion: chose)
        .fileDialogDefaultDirectory(FileManager.default.homeDirectoryForCurrentUser.appending(path: ".ssh", directoryHint: .isDirectory))
        .sheet(isPresented: $isSavingPassword, onDismiss: refresh) {
            if let passwords, let target = file.passwordTarget {
                SavePasswordSheet(passwords: passwords, sessionName: sessionName, target: target)
            }
        }
        .onAppear(perform: refresh)
    }

    private static let storedNote: String = "plink bekommt es beim Verbinden über eine Pipe, nie als Datei oder Argument. "
        + "Gehört es nicht mehr zu Benutzer, Server und Port der Sitzung, wird es nicht verwendet."

    private func refresh() {
        hasPassword = passwords?.contains(session: sessionName) ?? false
    }

    private func deletePassword() {
        passwords?.delete(session: sessionName)
        refresh()
    }

    /// plink lädt nur PuTTY-Schlüssel (.ppk); eine OpenSSH-Datei erst im Fenster „Schlüssel“ umwandeln.
    private func chose(_ result: Result<URL, any Error>) {
        guard case .success(let url) = result else { return }
        let start: Data = (try? FileHandle(forReadingFrom: url).read(upToCount: 32)) ?? Data()
        guard String(decoding: start, as: UTF8.self).hasPrefix("PuTTY-User-Key-File-") else {
            keyProblem = "Das ist kein PuTTY-Schlüssel (.ppk). OpenSSH-Schlüssel im Fenster „Schlüssel“ umwandeln."
            return
        }
        keyProblem = nil
        setKeyFile(url.path)
    }
}
