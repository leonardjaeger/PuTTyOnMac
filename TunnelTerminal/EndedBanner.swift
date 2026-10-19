import SwiftUI

/// Hinweis über dem Terminal, wenn die Verbindung beendet ist (Plan M1: „Erneut verbinden“).
struct EndedBanner: View {
    let message: String
    let reconnect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(message, systemImage: "bolt.horizontal.circle")
                Spacer()
                Button("Erneut verbinden", action: reconnect)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            Divider()
        }
        .background(.bar)
    }
}
