import SwiftUI
import TunnelTerminalCore

/// Abschnitt „Tunnel“ im Sitzungs-Editor (Plan M5): Tabelle der Port-Weiterleitungen und „auch für andere Rechner“.
/// Neue Einträge prüft der Kern (S3/S4); vorhandene bleiben unverändert, bis man sie entfernt.
struct TunnelEditorSection: View {
    let file: SessionFile
    /// Wendet eine Änderung über den Editor an (speichert); gibt eine Fehlermeldung zurück oder `nil`.
    let apply: ((inout SessionFile) throws -> Void) -> String?

    @State private var kind: PortForwarding.Kind = .local
    @State private var port: String = ""
    @State private var targetHost: String = ""
    @State private var targetPort: String = ""
    @State private var problem: String?
    @State private var acceptAll: Bool

    init(file: SessionFile, apply: @escaping ((inout SessionFile) throws -> Void) -> String?) {
        self.file = file
        self.apply = apply
        _acceptAll = State(initialValue: file.isOn(.localPortAcceptAll))
    }

    var body: some View {
        Section {
            let list: [PortForwarding] = file.portForwardings
            if list.isEmpty {
                Text("Keine Weiterleitungen")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(list.enumerated()), id: \.offset) { index, forwarding in
                LabeledContent(forwarding.kind.title) {
                    HStack {
                        Text(forwarding.title)
                            .monospaced()
                            .textSelection(.enabled)
                        Button("Entfernen", systemImage: "minus.circle") { remove(at: index) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .help("Weiterleitung entfernen")
                            .accessibilityLabel("Weiterleitung \(forwarding.title) entfernen")
                    }
                }
            }
            Picker("Art", selection: $kind) {
                ForEach(PortForwarding.Kind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            TextField(kind == .remote ? "Port auf dem Server" : "Port auf diesem Mac", text: $port, prompt: Text("8080"))
            if kind != .dynamic {
                TextField("Ziel", text: $targetHost, prompt: Text(kind == .remote ? "localhost" : "server.example"))
                TextField("Zielport", text: $targetPort, prompt: Text("80"))
            }
            HStack {
                ErrorText(problem)
                Spacer()
                Button("Hinzufügen", action: add)
                    .disabled(port.isEmpty)
            }
            Toggle("Lokale Ports auch für andere Rechner im Netz öffnen", isOn: $acceptAll)
            if acceptAll {
                Label("Jeder im selben Netz kann dann diese Weiterleitungen benutzen – bei „Dynamisch“ als offenen Proxy.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Tunnel")
        } footer: {
            Text(footer)
                .foregroundStyle(.secondary)
        }
        .onChange(of: acceptAll) { _, isOn in
            problem = apply { $0.setFlag(isOn, for: .localPortAcceptAll) }
        }
    }

    private var footer: String {
        let explanation: String = switch kind {
        case .local: "Lokal: Ein Port auf diesem Mac führt über den Server zum Ziel (z. B. zur Weboberfläche eines Geräts im Netz des Servers)."
        case .remote: "Entfernt: Ein Port auf dem Server führt zurück zu einem Ziel, das dieser Mac erreicht."
        case .dynamic: "Dynamisch: Ein SOCKS-Proxy auf diesem Mac; Programme wie ein Browser erreichen darüber alles, was der Server erreicht."
        }
        return explanation + " Änderungen gelten ab dem nächsten Verbinden; die Weiterleitungen stehen, sobald die Sitzung "
            + "begonnen hat (nach plinks „Press Return to begin session“)."
    }

    private func add() {
        guard let source = Int(port.trimmingCharacters(in: .whitespaces)) else {
            problem = InputError.invalidPort.message
            return
        }
        let destinationPort: Int = Int(targetPort.trimmingCharacters(in: .whitespaces)) ?? 0
        let host: String = targetHost.trimmingCharacters(in: .whitespaces)
        problem = apply { file in
            let forwarding: PortForwarding = try PortForwarding(kind: kind, port: source, targetHost: host,
                                                                targetPort: destinationPort)
            try file.addPortForwarding(forwarding)
        }
        if problem == nil {
            port = ""
            targetHost = ""
            targetPort = ""
        }
    }

    private func remove(at index: Int) {
        problem = apply { file in
            var list: [PortForwarding] = file.portForwardings
            guard list.indices.contains(index) else { return }
            list.remove(at: index)
            try file.setPortForwardings(list)
        }
    }
}
