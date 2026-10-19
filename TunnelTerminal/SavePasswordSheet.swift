import SwiftUI

/// Passwort einer Sitzung im Schlüsselbund sichern (Plan M3, freiwillig). Die Eingabe geht direkt in den
/// Schlüsselbund und wird danach geleert (S1).
struct SavePasswordSheet: View {
    let passwords: PasswordStore
    let sessionName: String
    /// `benutzer@server:port`, an das der Eintrag gebunden wird.
    let target: String

    @Environment(\.dismiss) private var dismiss
    @State private var password: String = ""
    @State private var failure: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Passwort für \(target) sichern")
                .font(.headline)
            Text("Beim nächsten Verbinden meldet plink dich damit an, ohne zu fragen. Fragt der Server danach noch einen zweiten Faktor ab, bietet die App an, ohne gespeichertes Passwort zu verbinden.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            SecureField("Passwort", text: $password)
                .focused($focused)
                .onSubmit(save)
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Im Schlüsselbund sichern", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
        .onAppear { focused = true }
    }

    private func save() {
        guard !password.isEmpty else { return }
        do {
            try passwords.save(password, session: sessionName, target: target)
            password = ""
            dismiss()
        } catch {
            failure = error.message
        }
    }
}
