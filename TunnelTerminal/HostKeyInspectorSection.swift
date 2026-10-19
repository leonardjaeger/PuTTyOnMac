import SwiftUI
import TunnelTerminalCore

/// Inspektor-Abschnitt „Hostschlüssel“ (Plan 3.1, M3): Typ und Fingerabdruck der bekannten Schlüssel des Servers
/// dieses Tabs. Die Prüfung selbst macht plink (S5); die App zeigt nur, was in `sshhostkeys` steht.
struct HostKeyInspectorSection: View {
    let info: ConnectionInfo

    var body: some View {
        Section("Hostschlüssel") {
            if info.hostKeys.isEmpty {
                Label("Noch nicht bekannt", systemImage: "questionmark.circle")
                Text("Beim ersten Verbinden zeigt plink den Fingerabdruck und fragt, ob es ihn sich merken soll. Vergleiche ihn vorher mit dem des Servers.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(info.hostKeys) { key in
                    LabeledContent(SessionWarning.visible(key.typeTitle)) {
                        Text(key.fingerprint ?? "nicht lesbar")
                            .monospaced()
                            .textSelection(.enabled)
                    }
                }
                Label("Bekannt – plink warnt, wenn er sich ändert", systemImage: "checkmark.shield")
                    .foregroundStyle(.green)
            }
            Button("Bekannte Hostschlüssel", action: showKnownHosts)
        }
    }

    private func showKnownHosts() {
        NSApp.sendAction(#selector(AppDelegate.showKnownHosts(_:)), to: nil, from: nil)
    }
}
