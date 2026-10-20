import SwiftUI
import TunnelTerminalCore

/// Inspektor-Abschnitt „Tunnel“ (Plan 3.1, M5): die Weiterleitungen der Sitzung dieses Tabs. Einen Status je
/// Weiterleitung meldet plink ohne `-v` nicht; die App prüft vor dem Verbinden nur, ob lokale Ports frei sind.
struct TunnelInspectorSection: View {
    let info: ConnectionInfo
    let forwardings: [PortForwarding]

    var body: some View {
        Section("Tunnel") {
            if forwardings.isEmpty {
                Text("Keine Weiterleitungen")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(forwardings.enumerated()), id: \.offset) { _, forwarding in
                LabeledContent(forwarding.kind.title) {
                    Text(forwarding.title)
                        .monospaced()
                        .textSelection(.enabled)
                }
                if let port = forwarding.listenPort, forwarding.kind != .remote, info.busyPorts.contains(port) {
                    Label("Port \(String(port)) war beim Verbinden belegt – diese Weiterleitung fehlt.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            if !forwardings.isEmpty {
                Text("Zeigt plink „Press Return to begin session“, stehen die Weiterleitungen erst nach Return.")
                    .foregroundStyle(.secondary)
            }
            if info.editableSession != nil {
                Button(forwardings.isEmpty ? "Hinzufügen …" : "Bearbeiten …", systemImage: "plus", action: editTunnels)
                    .help("Port-Weiterleitungen dieser Sitzung im Editor bearbeiten")
            }
        }
    }

    private func editTunnels() {
        NSApp.sendAction(#selector(ConnectionWindowController.editTunnels(_:)), to: nil, from: nil)
    }
}
