import SwiftUI

/// Rückfrage vor dem Einfügen von Text mit Zeilenumbrüchen (S10, Plan 3.1): Hinweisleiste über dem Terminal statt
/// Dialog. Tastatur: Esc bricht ab, ⌘↩ fügt ein (Return allein nicht, damit ein gewohntes Return nichts ausführt).
struct PasteBanner: View {
    let lines: Int
    let decide: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Warnung wie im Entwurf B (M7): Symbol in Orange, Text bleibt in der Textfarbe (Kontrast)
                Label {
                    Text(message)
                        .fixedSize(horizontal: false, vertical: true)   // umbrechen statt abschneiden
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
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
        .background(Color.orange.opacity(0.12))
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message)
    }

    /// Text auch für die VoiceOver-Ansage.
    var message: String {
        let count: String = lines == 1 ? "1 Zeile" : "\(lines) Zeilen"
        return "\(count) einfügen? Die Shell kann sie sofort ausführen."
    }

    private func cancel() { decide(false) }
    private func insert() { decide(true) }
}
