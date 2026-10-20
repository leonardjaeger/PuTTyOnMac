import SwiftUI

/// Statuszeile unter dem Terminal (Plan 3.1, M4; Anordnung wie Entwurf B seit M7): links Verbindung und Verbindungsart,
/// rechts Größe, Zeichensatz und Protokoll.
struct StatusBar: View {
    let info: ConnectionInfo

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Label(info.shortStatus, systemImage: info.isRunning ? "circle.fill" : "circle")
                    .foregroundStyle(info.isRunning && !info.isConnecting ? Color.green : Color.secondary)
                if let summary = info.summary {
                    Text(summary.protocolTitle)
                }
                Spacer()
                if let columns = info.columns, let rows = info.rows {
                    Text("\(columns) × \(rows)")
                        .monospacedDigit()
                        .accessibilityLabel("\(columns) Spalten, \(rows) Zeilen")
                }
                // SwiftTerm liest die Ausgabe immer als UTF-8; plink reicht die Bytes unverändert durch
                Text("UTF-8")
                Label(info.isLogging ? "Protokoll an" : "Protokoll aus",
                      systemImage: info.isLogging ? "doc.text.fill" : "doc.text")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .background(.bar)
        .accessibilityElement(children: .combine)
    }
}
