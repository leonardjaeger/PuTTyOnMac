import SwiftUI
import TunnelTerminalCore

/// Inspektor rechts im Hauptfenster (Plan 3.1): Abschnitte „Verbindung“ (M2) und „Hostschlüssel“ (M3, nur SSH);
/// weitere kommen mit ihren Funktionen (Tunnel M5, Dateien M6), nie als Platzhalter.
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
                    let fromKeychain: Bool = info.hasStoredPassword && summary.endsWithPassword
                    LabeledContent("Anmeldung", value: summary.authentication + (fromKeychain ? " aus dem Schlüsselbund" : ""))
                }
                if info.showsHostKeys {
                    HostKeyInspectorSection(info: info)
                }
            }
            .formStyle(.grouped)
        } else {
            ContentUnavailableView("Keine Verbindung", systemImage: "bolt.horizontal.circle",
                                   description: Text("Hier stehen die Angaben zur Verbindung dieses Tabs."))
        }
    }
}
