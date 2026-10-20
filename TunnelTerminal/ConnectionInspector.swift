import SwiftUI
import TunnelTerminalCore

/// Inspektor rechts im Hauptfenster (Plan 3.1): Abschnitte „Verbindung“ (M2, Profil seit M4) und „Hostschlüssel“ (M3, nur SSH);
/// „Tunnel“ (M5, nur SSH); „Dateien“ kommt mit M6, nie als Platzhalter.
struct ConnectionInspector: View {
    @Bindable var info: ConnectionInfo
    let profiles: ProfileStore

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
                    if summary.showsUser {
                        LabeledContent("Benutzer") {
                            if let user = summary.user {
                                Text(user)
                                    .monospaced()
                                    .textSelection(.enabled)
                            } else {
                                Text("Beim Verbinden fragen")
                            }
                        }
                    }
                    LabeledContent("Verbindungsart", value: summary.protocolTitle)
                    if let proxy = summary.proxy {
                        LabeledContent("Über", value: proxy)
                    }
                    let fromKeychain: Bool = info.hasStoredPassword && summary.endsWithPassword
                    LabeledContent("Anmeldung", value: summary.authentication + (fromKeychain ? " aus dem Schlüsselbund" : ""))
                    Picker("Profil", selection: $info.profileID) {
                        ForEach(profiles.profiles) { profile in
                            Text(SessionWarning.visible(profile.name)).tag(profile.id)
                        }
                    }
                    .help("Gilt für diesen Tab; dauerhaft im Sitzungs-Editor")
                }
                if info.showsHostKeys {
                    HostKeyInspectorSection(info: info)
                }
                if summary.showsTunnels && (info.editableSession != nil || !summary.portForwardings.isEmpty) {
                    TunnelInspectorSection(info: info, forwardings: summary.portForwardings)
                }
            }
            .formStyle(.grouped)
            .onChange(of: info.profileID) { _, id in info.selectProfile?(id) }
        } else {
            ContentUnavailableView("Keine Verbindung", systemImage: "bolt.horizontal.circle",
                                   description: Text("Hier stehen die Angaben zur Verbindung dieses Tabs."))
        }
    }
}
