import SwiftUI

/// Passwort für eine Dateiübertragung, wenn der Server eines verlangt (M6). Geht nur über die Pipe an pscp (S1) und
/// gilt nur für diese Übertragung; danach vergisst die App es.
struct TransferPasswordSheet: View {
    /// „benutzer@server“, sichtbar gemacht.
    let target: String
    /// Das gespeicherte Passwort wurde abgelehnt.
    let rejected: Bool
    let finish: (String?) -> Void

    @State private var password: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(rejected ? "Gespeichertes Passwort für \(target) nicht angenommen" : "Passwort für \(target)")
                .font(.headline)
            Text("Nur für diese Übertragung – die App speichert es nicht. Dauerhaft im Schlüsselbund: Sitzung bearbeiten › Anmeldung.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            SecureField("Passwort", text: $password)
                .focused($focused)
                .onSubmit(confirm)
            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Anmelden", action: confirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
        .onAppear { focused = true }
    }

    private func cancel() { finish(nil) }

    private func confirm() {
        guard !password.isEmpty else { return }
        let text: String = password
        password = ""
        finish(text)
    }
}
