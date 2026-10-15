import SwiftUI

/// Hinweis unter der Titelleiste, wenn die Verbindung beendet ist (Plan M1: „Erneut verbinden“).
struct EndedBanner: View {
    let message: String
    let reconnect: () -> Void

    var body: some View {
        HStack {
            Label(message, systemImage: "bolt.horizontal.circle")
            Spacer()
            Button("Erneut verbinden", action: reconnect)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}
