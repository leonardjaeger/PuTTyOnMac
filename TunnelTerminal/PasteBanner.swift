import SwiftUI

/// Rückfrage vor dem Einfügen von Text mit Zeilenumbrüchen (S10, Plan 3.1): Hinweisleiste über dem Terminal statt
/// Dialog. Tastatur: Esc bricht ab, ⌘↩ fügt ein (Return allein nicht, damit ein gewohntes Return nichts ausführt).
struct PasteBanner: View {
    let lines: Int
    let decide: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(message, systemImage: "doc.on.clipboard")
                Spacer()
                Button("Abbrechen", action: cancel)
                    .help("Esc")
                Button("Trotzdem einfügen", action: insert)
                    .help("⌘↩")
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            Divider()
        }
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message)
    }

    /// Text auch für die VoiceOver-Ansage.
    var message: String {
        let count: String = lines == 1 ? "1 Zeile" : "\(lines) Zeilen"
        return "Text mit Zeilenumbruch einfügen? \(count) – die Shell kann sie sofort ausführen."
    }

    private func cancel() { decide(false) }
    private func insert() { decide(true) }
}
