import SwiftUI

/// Befehl zum Abschreiben oder Kopieren (Monospace, auswählbar).
struct CommandText: View {
    let command: String

    var body: some View {
        Text(command)
            .monospaced()
            .textSelection(.enabled)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: .rect(cornerRadius: 6))
    }
}
