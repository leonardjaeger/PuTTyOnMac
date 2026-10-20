import SwiftUI

/// Meldung unter einem Feld bzw. in einem Editor-Abschnitt; ohne Meldung nichts.
struct ErrorText: View {
    let message: String?

    init(_ message: String?) {
        self.message = message
    }

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }
}
