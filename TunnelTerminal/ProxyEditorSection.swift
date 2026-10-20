import SwiftUI
import TunnelTerminalCore

/// Abschnitt „Proxy“ im Sitzungs-Editor (Plan M5): SOCKS, HTTP, SSH-Jump-Host (eine andere gespeicherte Sitzung) und
/// – nur mit deutlicher Warnung – ein lokaler Befehl (S4; vor jedem Verbinden fragt die App zusätzlich nach).
struct ProxyEditorSection: View {
    let file: SessionFile
    let sessionName: String
    /// Gespeicherte SSH-Sitzungen, die als Jump-Host in Frage kommen (ohne diese Sitzung).
    let jumpCandidates: [String]
    let apply: ((inout SessionFile) throws -> Void) -> String?

    @State private var kind: ProxyKind
    @State private var host: String
    @State private var port: String
    @State private var user: String
    @State private var command: String
    @State private var viaProxyToo: Bool
    @State private var problem: String?

    /// Werte im `init` übernehmen, nicht in `onAppear`: sonst schriebe schon das Öffnen Vorgaben in die Datei.
    init(file: SessionFile, sessionName: String, jumpCandidates: [String],
         apply: @escaping ((inout SessionFile) throws -> Void) -> String?) {
        self.file = file
        self.sessionName = sessionName
        self.jumpCandidates = jumpCandidates
        self.apply = apply
        _kind = State(initialValue: file.proxyKind)
        _host = State(initialValue: file.value(forKey: "ProxyHost") ?? "")
        _port = State(initialValue: String(file.proxyPort))
        _user = State(initialValue: file.proxyUsername)
        _command = State(initialValue: file.proxyCommand)
        _viaProxyToo = State(initialValue: file.isOn(.proxyLocalhost))
    }

    /// Telnet-Proxys bietet die App nicht neu an, zeigt einen importierten aber an.
    private var kinds: [ProxyKind] {
        [.none, .socks4, .socks5, .http, .ssh, .localCommand] + (kind == .telnet ? [.telnet] : [])
    }

    var body: some View {
        Section {
            Picker("Proxy", selection: $kind) {
                ForEach(kinds, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            switch kind {
            case .none:
                EmptyView()
            case .socks4, .socks5, .http, .telnet:
                TextField("Proxy-Server", text: $host, prompt: Text("proxy.example"))
                TextField("Proxy-Port", text: $port, prompt: Text("1080"))
                TextField("Proxy-Benutzer", text: $user, prompt: Text("Keiner"))
            case .ssh:
                Picker("Sprung über", selection: $host) {
                    if !jumpCandidates.contains(host) {
                        Text(file.proxyKind == .ssh ? "Server „\(SessionWarning.visible(file.proxyHost))“" : "Sitzung wählen")
                            .tag(host)
                    }
                    ForEach(jumpCandidates, id: \.self) { name in
                        Text(SessionWarning.visible(name)).tag(name)
                    }
                }
            case .localCommand:
                TextField("Befehl", text: $command, prompt: Text("nc %host %port"))
                    .monospaced()
                ForEach(Array(file.warnings.filter(\.isDangerous).enumerated()), id: \.offset) { _, warning in
                    Label(warning.message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            if kind != .none {
                Toggle("Auch Ziele auf diesem Mac über den Proxy", isOn: $viaProxyToo)
            }
            ErrorText(problem)
        } header: {
            Text("Proxy")
        } footer: {
            if kind != .none {
                Text(footer)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: kind) { _, new in kindChanged(to: new) }
        .onChange(of: host) { _, new in hostChanged(to: new) }
        .onChange(of: port) { _, new in
            problem = apply { try $0.setProxyPort(Int(new.trimmingCharacters(in: .whitespaces)) ?? 0) }
        }
        .onChange(of: user) { _, new in problem = apply { try $0.setProxyUsername(new.trimmingCharacters(in: .whitespaces)) } }
        .onChange(of: command) { _, new in problem = apply { try $0.setProxyCommand(new) } }
        .onChange(of: viaProxyToo) { _, isOn in problem = apply { $0.setFlag(isOn, for: .proxyLocalhost) } }
    }

    /// Jump-Host wird erst mit der gewählten Sitzung gespeichert (sonst gälte ein alter ProxyHost als Sprungziel).
    /// „Kein Proxy“ schaltet auch ein altes ProxyType ab; der Kern verwirft einen ProxyHost, der kein Server ist.
    private func kindChanged(to new: ProxyKind) {
        if new == .ssh {
            host = ""
            problem = apply { $0.disableProxy() }   // bis eine Sitzung gewählt ist: kein Proxy statt eines alten Ziels
            return
        }
        var stored: String = ""
        problem = apply { file in
            if new == .none { file.disableProxy() } else { try file.setProxyKind(new) }
            stored = file.value(forKey: "ProxyHost") ?? ""
        }
        host = stored
    }

    private func hostChanged(to new: String) {
        let trimmed: String = new.trimmingCharacters(in: .whitespaces)
        if kind == .ssh {
            if jumpCandidates.contains(trimmed) { problem = apply { try $0.setJumpHost(sessionNamed: trimmed) } }
        } else if !trimmed.isEmpty, trimmed != file.value(forKey: "ProxyHost") {
            problem = apply { try $0.setProxyHost(trimmed) }
        }
    }

    private var footer: String {
        var text: String = kind == .ssh
            ? "plink meldet sich zuerst am Jump-Host an (mit dessen Einstellungen) und verbindet von dort zum Server."
            : "Ein Proxy-Passwort speichert die App nicht; plink fragt bei Bedarf im Terminal."
        text += " Ohne den Schalter verbindet plink zu localhost und 127.0.0.1 direkt, nicht über den Proxy."
        text += " Ein Passwort aus dem Schlüsselbund nutzt die App mit Proxy nicht."
        return text
    }
}
