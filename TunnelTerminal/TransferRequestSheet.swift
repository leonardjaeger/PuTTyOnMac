import SwiftUI
import TunnelTerminalCore

/// Sheet vor einer Dateiübertragung (M6): Zielordner bzw. Datei auf dem Server, dazu der Benutzer, wenn die Sitzung
/// keinen nennt (pscp nähme sonst still den Benutzer dieses Macs, docs/M6-Machbarkeit.md 1).
struct TransferRequestSheet: View {
    /// Hochladen: Namen der Dateien; Herunterladen: `nil`.
    let uploads: [String]?
    /// „benutzer@server“ bzw. „server“, sichtbar gemacht.
    let server: String
    let needsUser: Bool
    let finish: (TransferRequest?) -> Void

    @State private var path: String
    @State private var user: String
    @State private var problem: String?

    init(uploads: [String]?, server: String, needsUser: Bool, path: String, user: String,
         finish: @escaping (TransferRequest?) -> Void) {
        self.uploads = uploads
        self.server = server
        self.needsUser = needsUser
        self.finish = finish
        _path = State(initialValue: path)
        _user = State(initialValue: user)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text("Server: \(server) (SFTP)")
                .foregroundStyle(.secondary)
            Form {
                TextField(uploads == nil ? "Datei auf dem Server" : "Zielordner auf dem Server", text: $path,
                          prompt: Text(uploads == nil ? "z. B. /var/log/syslog" : "leer = persönlicher Ordner"))
                if needsUser {
                    TextField("Benutzer", text: $user, prompt: Text("Die Sitzung nennt keinen Benutzer"))
                }
            }
            Text("Pfade ohne „/“ am Anfang gelten ab dem persönlichen Ordner.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ErrorText(problem)
            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button(uploads == nil ? "Weiter …" : "Hochladen", action: confirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 460)
    }

    private var title: String {
        guard let uploads else { return "Datei vom Server laden" }
        return uploads.count == 1 ? "„\(SessionWarning.visible(uploads[0]))“ hochladen" : "\(uploads.count) Dateien hochladen"
    }

    private func cancel() { finish(nil) }

    private func confirm() {
        do {
            let remote: RemotePath = try RemotePath(path)
            if uploads == nil, remote.localFileName == nil { throw InputError.notAFile }
            var checked: String? = nil
            if needsUser {
                let name: String = user.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { throw InputError.empty(.user) }
                var probe: SessionFile = SessionFile()
                try probe.setUserName(name)   // dieselben Regeln wie im Editor (S3)
                checked = name
            }
            finish(TransferRequest(path: remote, user: checked))
        } catch let error as InputError {
            problem = error.message
        } catch {
            problem = error.localizedDescription
        }
    }
}
