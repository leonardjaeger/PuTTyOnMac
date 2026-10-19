import SwiftUI
import TunnelTerminalCore

/// Inspektor rechts im Hauptfenster (Plan 3.1). In M2 nur der Abschnitt „Verbindung“; weitere Abschnitte kommen mit
/// ihren Funktionen (Hostschlüssel M3, Tunnel M5, Dateien M6), nie als Platzhalter.
struct ConnectionInspector: View {
    let info: ConnectionInfo

    var body: some View {
        if let summary = info.summary {
            Form {
                Section("Verbindung") {
                    LabeledContent("Status", value: info.statusText)
                    LabeledContent("Server") {
                        Text(summary.server)
                            .monospaced()
                            .textSelection(.enabled)
                    }
                    LabeledContent("Benutzer") {
                        if let user = summary.user {
                            Text(user)
                                .monospaced()
                                .textSelection(.enabled)
                        } else {
                            Text("Beim Verbinden fragen")
                        }
                    }
                    LabeledContent("Verbindungsart", value: summary.protocolTitle)
                    LabeledContent("Anmeldung", value: summary.authentication)
                }
            }
            .formStyle(.grouped)
        } else {
            ContentUnavailableView("Keine Verbindung", systemImage: "bolt.horizontal.circle",
                                   description: Text("Hier stehen die Angaben zur Verbindung dieses Tabs."))
        }
    }
}
