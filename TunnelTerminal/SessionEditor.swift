import SwiftUI
import TunnelTerminalCore

/// Editor einer gespeicherten Sitzung im PuTTY-Aufbau (im Sheet `SessionEditorSheet`), nur mit den häufig genutzten Feldern (Plan M2).
/// Jede gültige Änderung wird sofort gespeichert; der Name erst beim Bestätigen (Return, Feld verlassen oder Sheet schließen).
struct SessionEditor: View {
    private enum Field: Hashable {
        case title, group, host, port, user, terminalType, keepalive, remoteCommand
    }

    let model: SessionsModel
    let name: String
    /// Aus „Tunnel bearbeiten …“: zum Abschnitt „Tunnel“ blättern (M5).
    var showsTunnels: Bool = false

    @State private var file: SessionFile
    @State private var title: String
    @State private var group: String
    @State private var host: String
    @State private var port: String
    @State private var user: String
    @State private var connectionProtocol: ConnectionProtocol?
    @State private var terminalType: String
    @State private var keepalive: String
    @State private var remoteCommand: String
    @State private var tcpKeepalives: Bool
    @State private var compression: Bool
    @State private var agentForwarding: Bool
    @State private var profileID: UUID
    @State private var sessionLog: Bool
    @State private var errors: [Field: String] = [:]
    @FocusState private var focus: Field?

    init(model: SessionsModel, name: String, file: SessionFile, showsTunnels: Bool = false) {
        self.model = model
        self.name = name
        self.showsTunnels = showsTunnels
        _file = State(initialValue: file)
        _title = State(initialValue: SessionName.title(of: name))
        _group = State(initialValue: SessionName.group(of: name) ?? "")
        _host = State(initialValue: file.hostName)
        _port = State(initialValue: String(file.portNumber))
        _user = State(initialValue: file.userName)
        _connectionProtocol = State(initialValue: file.connectionProtocol)
        _terminalType = State(initialValue: file.terminalType)
        _keepalive = State(initialValue: String(file.keepaliveSeconds))
        _remoteCommand = State(initialValue: file.remoteCommand)
        _tcpKeepalives = State(initialValue: file.tcpKeepalives)
        _compression = State(initialValue: file.compression)
        _agentForwarding = State(initialValue: file.agentForwarding)
        _profileID = State(initialValue: model.profiles.profile(id: file.profileID).id)
        _sessionLog = State(initialValue: file.sessionLogEnabled)
    }

    private var isDefaultSettings: Bool { name == SessionName.defaultSettings }

    /// Gespeicherte SSH-Sitzungen außer dieser (Jump-Host, M5); Schleifen über mehrere Sitzungen lehnt das Verbinden ab.
    private var jumpCandidates: [String] {
        model.library.names.filter { $0 != name && $0 != SessionName.defaultSettings
            && model.library.file(named: $0)?.connectionProtocol == .ssh }
    }

    var body: some View {
        ScrollViewReader { reader in
            Form {
                if !file.warnings.isEmpty {
                    Section("Hinweise") {
                        ForEach(Array(file.warnings.enumerated()), id: \.offset) { _, warning in
                            Label(warning.message, systemImage: warning.isDangerous ? "exclamationmark.triangle.fill" : "info.circle")
                                .foregroundStyle(warning.isDangerous ? Color.orange : Color.primary)
                        }
                    }
                }
                Section("Sitzung") {
                    if isDefaultSettings {
                        LabeledContent("Name", value: "Standardeinstellungen")
                    } else {
                        TextField("Name", text: $title)
                            .focused($focus, equals: .title)
                            .onSubmit(commitName)
                        TextField("Gruppe", text: $group, prompt: Text("Keine"))
                            .focused($focus, equals: .group)
                            .onSubmit(commitName)
                        ErrorText(errors[.title])
                    }
                    if connectionProtocol != .serial {
                        TextField("Server", text: $host, prompt: Text("server.example"))
                            .focused($focus, equals: .host)
                        ErrorText(errors[.host])
                    }
                    Picker("Protokoll", selection: $connectionProtocol) {
                        ForEach(ConnectionProtocol.allCases) { option in
                            Text(option.title).tag(Optional(option))
                        }
                        if connectionProtocol == nil {
                            Text("Anderes (\(file.value(forKey: "Protocol") ?? ""))").tag(ConnectionProtocol?.none)
                        }
                    }
                    if connectionProtocol != .serial {
                        TextField("Port", text: $port)
                            .focused($focus, equals: .port)
                        ErrorText(errors[.port])
                        TextField("Benutzername", text: $user, prompt: Text("Beim Verbinden fragen"))
                            .focused($focus, equals: .user)
                        ErrorText(errors[.user])
                    }
                }
                if connectionProtocol == .serial {
                    SerialEditorSection(file: file, apply: apply)
                }
                Section {
                    TextField("Terminaltyp", text: $terminalType)
                        .focused($focus, equals: .terminalType)
                    ErrorText(errors[.terminalType])
                    Picker("Profil", selection: $profileID) {
                        ForEach(model.profiles.profiles) { profile in
                            Text(SessionWarning.visible(profile.name)).tag(profile.id)
                        }
                    }
                    Toggle("Sitzungsprotokoll", isOn: $sessionLog)
                } header: {
                    Text("Terminal")
                } footer: {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Das Protokoll enthält alles, was im Terminal erscheint – auch getippte Befehle, nicht aber verdeckte "
                             + "Eingaben wie Passwörter.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Protokolle zeigen", action: revealLogs)
                    }
                }
                if connectionProtocol != .serial {
                    Section("Verbindung") {
                        TextField("Keepalive alle (Sekunden)", text: $keepalive, prompt: Text("0 = aus"))
                            .focused($focus, equals: .keepalive)
                        ErrorText(errors[.keepalive])
                        Toggle("TCP-Keepalives", isOn: $tcpKeepalives)
                    }
                    SessionAuthenticationSection(file: file, sessionName: name, passwords: model.library.passwords) { path in
                        update(nil) { try $0.setPublicKeyFile(path) }
                    }
                    if connectionProtocol == .ssh || isDefaultSettings {
                        TunnelEditorSection(file: file, apply: apply)
                            .id(Self.tunnelSection)
                    }
                    ProxyEditorSection(file: file, sessionName: name, jumpCandidates: jumpCandidates, apply: apply)
                    Section {
                        Toggle("Komprimierung", isOn: $compression)
                        Toggle("Agent-Weiterleitung", isOn: $agentForwarding)
                        TextField("Befehl auf dem Server", text: $remoteCommand, prompt: Text("Shell starten"))
                            .focused($focus, equals: .remoteCommand)
                        ErrorText(errors[.remoteCommand])
                    } header: {
                        Text("SSH")
                    } footer: {
                        Text(otherValuesText)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .onAppear {
                if showsTunnels { reader.scrollTo(Self.tunnelSection, anchor: .top) }
            }
        }
        .autocorrectionDisabled()
        .onChange(of: focus) { old, new in
            // Tab zwischen Name und Gruppe benennt noch nicht um, erst das Verlassen beider Felder
            let nameFields: Set<Field> = [.title, .group]
            if let old, nameFields.contains(old), !(new.map(nameFields.contains) ?? false) { commitName() }
        }
        .onChange(of: host) { update(.host) { try $0.setHostName(host.trimmingCharacters(in: .whitespaces)) } }
        .onChange(of: port) { update(.port) { try $0.setPortNumber(try number(port, else: .invalidPort)) } }
        .onChange(of: user) { update(.user) { try $0.setUserName(user.trimmingCharacters(in: .whitespaces)) } }
        .onChange(of: connectionProtocol) { old, new in protocolChanged(from: old, to: new) }
        .onChange(of: terminalType) { update(.terminalType) { try $0.setTerminalType(terminalType) } }
        .onChange(of: keepalive) {
            update(.keepalive) { try $0.setKeepaliveSeconds(try number(keepalive, else: .outOfRange(.keepalive))) }
        }
        .onChange(of: remoteCommand) { update(.remoteCommand) { try $0.setRemoteCommand(remoteCommand) } }
        .onChange(of: tcpKeepalives) { update(nil) { $0.setFlag(tcpKeepalives, for: .tcpKeepalives) } }
        .onChange(of: compression) { update(nil) { $0.setFlag(compression, for: .compression) } }
        .onChange(of: agentForwarding) { update(nil) { $0.setFlag(agentForwarding, for: .agentForwarding) } }
        .onChange(of: profileID) {
            update(nil) { try $0.setProfileID(profileID == TerminalProfile.standardID ? nil : profileID) }
        }
        .onChange(of: sessionLog) { update(nil) { $0.setSessionLog(sessionLog) } }
        // „Fertig“/Esc schließt das Sheet, ohne dass ein Namensfeld verlassen wurde: Namen trotzdem übernehmen.
        // Nach einem Umbenennen baut sich der Editor neu auf; der alte Name existiert dann nicht mehr.
        .onDisappear {
            if model.library.names.contains(name) { applyName(reportingFailure: true) }
        }
    }

    /// Ordner der Sitzungsprotokolle im Finder (wird angelegt, falls es ihn noch nicht gibt).
    private func revealLogs() {
        let folder: URL = SessionLogWriter.folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    private var otherValuesText: String {
        let count: Int = file.otherEntryCount
        return count == 1 ? "1 weiterer Wert bleibt unverändert." : "\(count) weitere Werte bleiben unverändert."
    }

    private static let tunnelSection: String = "tunnel"

    /// Änderung anwenden und speichern; Meldung oder `nil` zurück (auch für die Abschnitte Tunnel, Proxy, Seriell, M5).
    private func apply(_ change: (inout SessionFile) throws -> Void) -> String? {
        var changed: SessionFile = file
        do {
            try change(&changed)
            guard changed != file else { return nil }
            try model.save(changed, as: name)
            file = changed
            return nil
        } catch {
            return (error as? InputError)?.message ?? error.localizedDescription
        }
    }

    /// Wendet eine Änderung an und speichert, wenn sie gültig ist; sonst erscheint die Meldung unter dem Feld.
    private func update(_ field: Field?, _ change: (inout SessionFile) throws -> Void) {
        let message: String? = apply(change)
        if let field { errors[field] = message } else if let message { model.report(message: message) }
    }

    private func number(_ text: String, else failure: InputError) throws(InputError) -> Int {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)) else { throw failure }
        return value
    }

    /// Wie in PuTTY: Stand der Port auf dem Standard des alten Protokolls, folgt er dem neuen.
    private func protocolChanged(from old: ConnectionProtocol?, to new: ConnectionProtocol?) {
        guard let new else { return }
        update(nil) { $0.setConnectionProtocol(new) }
        if let oldPort = old?.defaultPort, port == String(oldPort), let newPort = new.defaultPort {
            port = String(newPort)
        }
    }

    private func commitName() { applyName(reportingFailure: false) }

    /// `reportingFailure`: Fehler als Meldung statt unter dem Feld (das Sheet ist dann schon zu).
    private func applyName(reportingFailure: Bool) {
        let newName: String = SessionName.make(group: group.trimmingCharacters(in: .whitespaces),
                                               title: title.trimmingCharacters(in: .whitespaces))
        guard !isDefaultSettings, newName != name else {
            errors[.title] = nil
            return
        }
        do {
            try model.rename(name, to: newName)
        } catch {
            if reportingFailure { model.report(error) } else {
                errors[.title] = (error as? InputError)?.message ?? error.localizedDescription
            }
        }
    }
}

