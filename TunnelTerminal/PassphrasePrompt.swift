import SwiftUI

/// Abfrage der Passphrase eines Schlüssels (Sheet am Fenster „Schlüssel“). Der Text geht direkt an puttygen
/// (über eine Pipe, S1) und wird nicht gespeichert.
struct PassphrasePrompt: View {
    let request: KeysModel.PassphraseRequest
    let answer: (String) -> Void
    let cancel: () -> Void

    @State private var passphrase: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(request.wasWrong ? "Die Passphrase war falsch. Bitte noch einmal eingeben." : "Passphrase für den Schlüssel")
                .font(.headline)
            SecureField("Passphrase", text: $passphrase)
                .focused($focused)
                .onSubmit(confirm)
            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Weiter", action: confirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(passphrase.isEmpty)
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear { focused = true }
    }

    private func confirm() {
        guard !passphrase.isEmpty else { return }
        let text: String = passphrase
        passphrase = ""
        answer(text)
    }
}
