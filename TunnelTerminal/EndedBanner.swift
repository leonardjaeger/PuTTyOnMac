import SwiftUI

/// Hinweis über dem Terminal, wenn die Verbindung beendet ist (Plan M1: „Erneut verbinden“).
/// Nach einem abgelehnten gespeicherten Passwort zusätzlich „Ohne gespeichertes Passwort verbinden“ (M3, M0 B12).
struct EndedBanner: View {
    let message: String
    let reconnect: () -> Void
    var reconnectWithoutStoredPassword: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(message, systemImage: "bolt.horizontal.circle")
                Spacer()
                if let reconnectWithoutStoredPassword {
                    Button("Ohne gespeichertes Passwort verbinden", action: reconnectWithoutStoredPassword)
                }
                Button("Erneut verbinden", action: reconnect)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            Divider()
        }
        .background(.bar)
    }
}
