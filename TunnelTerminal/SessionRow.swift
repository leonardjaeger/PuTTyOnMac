import SwiftUI

/// Zeile einer gespeicherten Sitzung: Titel, Server (beide schon über `SessionWarning.visible`), rechts die
/// Verbindungsart (Entwurf B, M7) und Status. Verbunden = gefüllter grüner Punkt, sonst ein leerer Kreis – unterscheidbar
/// auch ohne Farbe.
struct SessionRow: View {
    let title: String
    let host: String
    let protocolTitle: String?
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isConnected ? "circle.fill" : "circle")
                .font(.system(size: 7))
                .foregroundStyle(isConnected ? Color.green : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(title)
                if !host.isEmpty {
                    Text(host)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if let protocolTitle {
                Text(protocolTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isConnected ? "verbunden" : "")
    }
}
