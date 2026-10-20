import AppKit
import TunnelTerminalCore
import SwiftTerm
import SwiftUI
import UniformTypeIdentifiers

/// Hauptfenster bzw. ein Tab, Gerüst B „Werkbank“ (Plan 3.1): links die Seitenleiste mit Schnellverbindung und
/// Sitzungen, in der Mitte Startansicht bzw. Terminal, rechts der Inspektor. Menübefehle zu Sitzungen und zur
/// Verbindung landen hier über die Responder-Kette.
final class ConnectionWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation,
    NSToolbarItemValidation, NSToolbarDelegate, TerminalViewDelegate {
    /// Gemeinsame Kennung, damit macOS die Fenster zu Tabs zusammenfasst.
    static let tabbingIdentifier: String = "Verbindung"

    /// Was ein Tab öffnen soll: eine geprüfte Schnellverbindung oder eine gespeicherte Sitzung.
    enum Opening {
        case connection(Connection)
        case savedSession(String)
    }

    var onClose: ((ConnectionWindowController) -> Void)?
    /// Dieser Tab ist schon verbunden: die Verbindung in einem neuen Tab daneben öffnen (App-Delegate).
    var onOpenInNewTab: ((Opening, ConnectionWindowController) -> Void)?

    let sessions: SessionsModel
    let quick: QuickConnect
    private let connected: ConnectedSessions
    private let profiles: ProfileStore
    private let info: ConnectionInfo = ConnectionInfo()
    private let split: NSSplitViewController = NSSplitViewController()
    private let sidebarItem: NSSplitViewItem
    private let inspectorItem: NSSplitViewItem
    private let area: TerminalArea = TerminalArea()

    private var connection: Connection?
    private(set) var terminal: AppTerminalView?
    /// Eigener Titel des Tabs („Titel ändern …“, M4); `nil` = Adresse bzw. Sitzungsname.
    private var customTitle: String?
    /// Text, der auf die Bestätigung in der Hinweisleiste wartet (S10).
    private var pendingPaste: String?
    /// Tasten vor SwiftTerm: Hinweisleiste (Esc, ⌘↩) und F1–F4 (`AppTerminalView.handleKey`).
    private var keyMonitor: Any?
    /// OSC 52 einmal abgelehnt: weitere Wünsche dieser Verbindung ohne Rückfrage verwerfen (sonst sperrt ein Server
    /// den Tab mit endlosen Rückfragen, Prüfer-Befund 3).
    private var clipboardRefused: Bool = false
    /// Gespeicherte Sitzung, die für den Status in der Seitenleiste als verbunden zählt.
    private var countedSession: String?
    private var closingConfirmed: Bool = false
    /// Server und Port, deren bekannte Hostschlüssel der Inspektor zeigt (nur SSH, M3).
    private var hostKeyServer: (host: String, port: Int)?
    private var lastHostKeyCheck: Date = .distantPast
    /// Seriell: Das Gerät ist mit dem Start offen und schweigt oft, bis man tippt (kein „Verbinde …“ bis zur Ausgabe).
    private var opensInstantly: Bool = false

    private static let registryType: UTType = UTType(filenameExtension: "reg") ?? .data
    private static let disconnectItem: NSToolbarItem.Identifier = NSToolbarItem.Identifier("trennen")
    private static let tunnelItem: NSToolbarItem.Identifier = NSToolbarItem.Identifier("tunnel")

    var isConnected: Bool { connection?.isRunning ?? false }
    var showsSidebar: Bool { !sidebarItem.isCollapsed }
    var showsInspector: Bool { !inspectorItem.isCollapsed }

    /// Adresse und Protokoll der Verbindung dieses Tabs (zum Vorbelegen eines neuen Tabs).
    var address: (text: String, connectionProtocol: ConnectionProtocol)? {
        connection?.quickAddress
    }

    init(library: SessionLibrary, connected: ConnectedSessions, profiles: ProfileStore = AppIdentity.profiles,
         address: String = "", connectionProtocol: ConnectionProtocol = .ssh, showsSidebar: Bool = true,
         showsInspector: Bool = true) {
        sessions = SessionsModel(library: library, profiles: profiles)
        quick = QuickConnect(address: address, connectionProtocol: connectionProtocol)
        self.connected = connected
        self.profiles = profiles

        let sidebar: NSHostingController<SessionSidebar> = NSHostingController(
            rootView: SessionSidebar(model: sessions, quick: quick, connected: connected))
        sidebar.sizingOptions = []   // keine Größenbindung an den SwiftUI-Inhalt (Richtlinien 3.4 Regel 19)
        sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 210
        sidebarItem.maximumThickness = 360
        sidebarItem.isCollapsed = !showsSidebar

        let content: NSSplitViewItem = NSSplitViewItem(viewController: area)
        content.minimumThickness = 360

        let inspector: NSHostingController<ConnectionInspector> = NSHostingController(
            rootView: ConnectionInspector(info: info, profiles: profiles))
        inspector.sizingOptions = []
        inspectorItem = NSSplitViewItem(inspectorWithViewController: inspector)
        inspectorItem.minimumThickness = 220
        inspectorItem.maximumThickness = 340
        inspectorItem.isCollapsed = !showsInspector

        split.addSplitViewItem(sidebarItem)
        split.addSplitViewItem(content)
        split.addSplitViewItem(inspectorItem)

        let window: NSWindow = NSWindow(contentViewController: split)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "Neue Verbindung"
        window.tabbingIdentifier = Self.tabbingIdentifier
        window.isRestorable = false
        window.setContentSize(NSSize(width: 1180, height: 680))
        window.minSize = NSSize(width: 820, height: 360)
        super.init(window: window)

        let toolbar: NSToolbar = NSToolbar(identifier: "Hauptfenster")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.delegate = self

        sessions.undoManager = { [weak window] in window?.undoManager }
        sessions.onConnect = { [weak self] name in self?.request(.savedSession(name)) }
        sessions.onImport = { [weak self] source in
            switch source {
            case .registry: self?.importRegistry(nil)
            case .folder: self?.importFolder(nil)
            }
        }
        sessions.revealSidebar = { [weak self] in self?.sidebarItem.isCollapsed = false }
        quick.connect = { [weak self] text, choice in self?.connectQuick(text, using: choice) }
        info.selectProfile = { [weak self] _ in self?.applyProfile() }
        NotificationCenter.default.addObserver(self, selector: #selector(profilesChanged(_:)),
                                               name: ProfileStore.didChange, object: profiles)

        let start: NSHostingView<StartView> = NSHostingView(rootView: StartView(model: sessions))
        start.sizingOptions = []
        area.show(start)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht benutzt") }

    // MARK: - Verbinden

    /// Noch nichts verbunden: Eine Verbindung aus der Seitenleiste kommt in diesen Tab, sonst in einen neuen.
    private var isFree: Bool { terminal == nil }

    /// Derselbe PuTTY-Ordner wie die Seitenleiste: Rückfrage (S4), Inspektor und plink lesen, was die Liste zeigt.
    private var puttyDirectory: @MainActor () throws -> PuTTYDirectory {
        let directory: PuTTYDirectory = sessions.library.directory
        return { directory }
    }

    private func request(_ opening: Opening) {
        if isFree { open(opening) } else { onOpenInNewTab?(opening, self) }
    }

    /// Prüft die Adresse der Schnellverbindung. Gibt eine Fehlermeldung für das Feld zurück.
    private func connectQuick(_ text: String, using choice: ConnectionProtocol) -> String? {
        do {
            request(.connection(try Connection(endpoint: try Endpoint(parsing: text), connectionProtocol: choice,
                                               puttyDirectory: puttyDirectory)))
            return nil
        } catch {
            return error.message
        }
    }

    /// Öffnet eine Verbindung in diesem Tab. Erst aufrufen, wenn das Fenster sichtbar ist (Rückfrage als Sheet).
    func open(_ opening: Opening) {
        showTerminal()
        switch opening {
        case .connection(let newConnection):
            confirmAndStart(newConnection)
        case .savedSession(let name):
            do {
                confirmAndStart(try Connection(savedSession: name, puttyDirectory: puttyDirectory))
            } catch {
                window?.title = SessionWarning.visible(name)
                connectionEnded(error.message)
            }
        }
    }

    /// Ein lokaler Proxy-Befehl oder eine eigene GSSAPI-Bibliothek (auch in einer Proxy-Sitzung) führt etwas auf diesem
    /// Mac aus: vor jedem Verbinden fragen (S4), alle Gefahren zeigen. Ist eine Sitzung nicht lesbar, nicht verbinden.
    private func confirmAndStart(_ newConnection: Connection) {
        let warnings: [SessionWarning]
        do {
            warnings = try newConnection.warningsRequiringConfirmation()
        } catch {
            prepare(newConnection)
            let reason: String = (error as? InputError) == .proxyLoop ? error.message : "Die Sitzung ist nicht lesbar (\(error.message))"
            connectionEnded("Nicht verbunden: \(reason)")
            return
        }
        guard !warnings.isEmpty else {
            start(newConnection)
            return
        }
        guard let window else { return }   // ohne Fenster keine Rückfrage, also auch kein Verbinden
        prepare(newConnection)
        let alert: NSAlert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "„\(SessionWarning.visible(newConnection.displayName))“ führt beim Verbinden etwas auf diesem Mac aus."
        alert.informativeText = warnings.map(\.message).joined(separator: "\n\n")
            + "\n\nNur verbinden, wenn du das kennst und ihm vertraust."
        alert.addButton(withTitle: "Abbrechen")
        alert.addButton(withTitle: "Verbinden")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            if response == .alertSecondButtonReturn {
                self.start(newConnection)
            } else {
                self.connectionEnded("Nicht verbunden.")
            }
        }
    }

    /// Titel und Inspektor zeigen die Verbindung, auch bevor sie läuft.
    private func prepare(_ newConnection: Connection) {
        // Dieselbe Verbindung noch einmal (⌘R): die Profil-Wahl im Inspektor bleibt für den Tab
        let sameTarget: Bool = connection?.target == newConnection.target
        connection = newConnection
        clipboardRefused = false
        window?.title = defaultTitle
        let settings: SessionFile? = newConnection.settings()
        info.summary = settings.map(ConnectionSummary.init(file:))
        if !sameTarget { info.profileID = profiles.profile(id: settings?.profileID).id }
        applyProfile()
        info.hasStoredPassword = newConnection.hasStoredPassword
        info.busyPorts = []
        info.editableSession = savedSessionName(of: newConnection)
        hostKeyServer = settings?.hostKeyServer
        opensInstantly = settings?.connectionProtocol == .serial
        refreshHostKeys()
    }

    /// Liest `sshhostkeys` neu (klein, Lesen ist billig). Während der Server noch unbekannt ist, nach jeder Ausgabe
    /// höchstens einmal pro Sekunde: So erscheint der Schlüssel, sobald man ihn in plinks Abfrage bestätigt hat.
    private func refreshHostKeys() {
        info.showsHostKeys = hostKeyServer != nil
        lastHostKeyCheck = .now
        guard let hostKeyServer, let keys = try? puttyDirectory().knownHostKeys() else {
            info.hostKeys = []
            return
        }
        info.hostKeys = keys.entries(host: hostKeyServer.host, port: hostKeyServer.port)
    }

    private func outputArrived() {
        if info.isConnecting { info.isConnecting = false }
        if info.isLogging, connection?.log == nil { info.isLogging = false }   // Protokoll an der Grenze angehalten
        if hostKeyServer != nil, info.hostKeys.isEmpty, Date.now.timeIntervalSince(lastHostKeyCheck) >= 1 { refreshHostKeys() }
    }

    private func showTerminal() {
        guard terminal == nil else { return }
        let view: AppTerminalView = AppTerminalView(frame: area.view.bounds)
        view.terminalDelegate = self
        view.setAccessibilityLabel("Terminal")
        view.onPaste = { [weak self] text in self?.requestPaste(text) }
        view.onPasteDecision = { [weak self] insert in self?.finishPaste(insert) }
        view.onFunctionKey = { [weak self] number in self?.functionKey(number) }
        view.apply(profiles.profile(id: info.profileID))
        area.show(view)
        let status: NSHostingView<StatusBar> = NSHostingView(rootView: StatusBar(info: info))
        status.sizingOptions = [.intrinsicContentSize]
        area.showStatus(status)
        window?.makeFirstResponder(view)
        window?.layoutIfNeeded()
        terminal = view
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak view] event in
            view?.handleKey(event) == true ? nil : event
        }
    }

    /// Profil des Tabs auf das Terminal übertragen (beim Verbinden, nach Wahl im Inspektor, nach Änderungen).
    private func applyProfile() {
        terminal?.apply(profiles.profile(id: info.profileID))
    }

    @objc private func profilesChanged(_ notification: Notification) {
        // ein gelöschtes Profil: zurück auf das Standardprofil
        info.profileID = profiles.profile(id: info.profileID).id
        applyProfile()
    }

    private func start(_ newConnection: Connection) {
        // nie zwei plink in einem Tab: das erste ließe sich sonst nicht mehr trennen
        guard let terminal, connection?.isRunning != true else { return }
        prepare(newConnection)
        newConnection.onOutput = { [weak terminal, weak self] bytes in
            terminal?.feed(byteArray: bytes)
            self?.outputArrived()
        }
        newConnection.onEnd = { [weak self] message in self?.connectionEnded(message) }
        let size: TerminalDimensions = terminal.terminalDimensions
        do {
            try newConnection.start(columns: size.cols, rows: size.rows)
        } catch {
            AppLog.connection.error("Start fehlgeschlagen")
            connectionEnded(error.message)
            return
        }
        info.isRunning = true
        info.isConnecting = !opensInstantly
        info.endMessage = nil
        info.hasStoredPassword = newConnection.usesStoredPassword
        info.isLogging = newConnection.log != nil
        info.busyPorts = newConnection.busyLocalPorts
        info.columns = size.cols
        info.rows = size.rows
        if case .saved(let name) = newConnection.target {
            connected.started(name)
            countedSession = name
        }
    }

    private func connectionEnded(_ message: String) {
        releaseCountedSession()
        finishPaste(false)
        info.isRunning = false
        info.isConnecting = false
        info.isLogging = false
        info.endMessage = message
        refreshHostKeys()
        showBanner(message)
        NSAccessibility.post(element: window as Any, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    private func releaseCountedSession() {
        if let countedSession { connected.ended(countedSession) }
        countedSession = nil
    }

    private func showBanner(_ message: String) {
        var banner: EndedBanner = EndedBanner(message: message) { [weak self] in self?.reconnect(nil) }
        if connection?.storedPasswordRejected == true {
            banner.reconnectWithoutStoredPassword = { [weak self] in self?.reconnect(withStoredPassword: false) }
        }
        let content: NSHostingView<EndedBanner> = NSHostingView(rootView: banner)
        content.sizingOptions = [.intrinsicContentSize]
        area.showBanner(content)
    }

    // MARK: - Menübefehle: Verbindung

    @objc func reconnect(_ sender: Any?) {
        reconnect(withStoredPassword: true)
    }

    /// `withStoredPassword: false` nach einem abgelehnten gespeicherten Passwort (2FA, falsches Passwort): plink fragt.
    private func reconnect(withStoredPassword: Bool) {
        // Während einer Rückfrage (Sheet) nicht noch eine stellen
        guard window?.attachedSheet == nil, let previous = connection, !previous.isRunning else { return }
        area.showBanner(nil)
        terminal?.feed(text: "\r\n")
        do {
            confirmAndStart(try previous.again(withStoredPassword: withStoredPassword))
        } catch {
            connectionEnded(error.message)
        }
    }

    @objc func disconnect(_ sender: Any?) {
        connection?.hangUp()
    }

    /// Symbolleiste „Tunnel“ bzw. Verbindung › Tunnel bearbeiten … (M5): Editor der Sitzung dieses Tabs beim Abschnitt
    /// „Tunnel“. Änderungen gelten ab dem nächsten Verbinden (plink liest die Sitzung nur beim Start).
    @objc func editTunnels(_ sender: Any?) {
        guard window?.attachedSheet == nil, canEditTunnels, let name = info.editableSession else { return }
        sessions.edit(name, showingTunnels: true)
    }

    /// Gespeicherte SSH-Sitzung im Tab (nur dort wirken Weiterleitungen).
    private var canEditTunnels: Bool { info.editableSession != nil && info.summary?.showsTunnels == true }

    private func savedSessionName(of connection: Connection) -> String? {
        if case .saved(let name) = connection.target { name } else { nil }
    }

    /// ⇧⌘K: Fokus in die Schnellverbindung (blendet die Seitenleiste ein).
    @objc func focusQuickConnect(_ sender: Any?) {
        sidebarItem.isCollapsed = false
        quick.requestFocus()
    }

    // MARK: - Menübefehle: Terminal (M4)

    /// ⌘K wie Terminal.app: Bildschirm und Verlauf leeren (nur in der App; der Server merkt davon nichts).
    @objc func clearScreenAndHistory(_ sender: Any?) {
        terminal?.feed(text: "\u{1B}[H\u{1B}[2J\u{1B}[3J")
    }

    /// Bearbeiten › Alles kopieren: Verlauf und Bildschirm als Text (wie „Copy All to Clipboard“ in PuTTY).
    @objc func copyEverything(_ sender: Any?) {
        guard let terminal else { return }
        let text: String = Self.trimmed(String(decoding: terminal.getBufferAsData(kind: .active), as: UTF8.self))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Leerraum am Zeilenende und leere Zeilen am Schluss weg (das Terminal füllt Zeilen bis zur Breite auf).
    static func trimmed(_ buffer: String) -> String {
        var lines: [String] = buffer.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            var text: String = String(line)
            while text.last == " " { text.removeLast() }
            return text
        }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    /// ⌘D: dieselbe Verbindung in einem neuen Tab (Idee F3 aus dem Fork).
    @objc func duplicateConnection(_ sender: Any?) {
        guard let connection else { return }
        do {
            onOpenInNewTab?(.connection(try connection.again()), self)
        } catch {
            sessions.report(error)
        }
    }

    /// Fenster › Titel ändern … (Idee F4 aus dem Fork); leer = wieder Adresse bzw. Sitzungsname.
    @objc func changeTitle(_ sender: Any?) {
        guard let window, window.attachedSheet == nil else { return }
        let alert: NSAlert = NSAlert()
        alert.messageText = "Titel ändern"
        alert.informativeText = "Leer lassen, um wieder den Namen der Verbindung zu zeigen."
        let field: NSTextField = NSTextField(string: customTitle ?? "")
        field.placeholderString = window.title
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        field.setAccessibilityLabel("Titel")
        alert.accessoryView = field
        alert.addButton(withTitle: "Ändern")
        alert.addButton(withTitle: "Abbrechen")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.setCustomTitle(field.stringValue)
        }
    }

    func setCustomTitle(_ text: String) {
        let trimmed: String = text.trimmingCharacters(in: .whitespaces)
        customTitle = trimmed.isEmpty ? nil : String(SessionWarning.visible(trimmed).prefix(100))
        window?.title = defaultTitle
    }

    /// Eigener Titel, sonst Adresse bzw. Sitzungsname.
    private var defaultTitle: String {
        customTitle ?? connection.map { SessionWarning.visible($0.displayName) } ?? "Neue Verbindung"
    }

    /// Suchen (⌘F, ⌘G …) auch, wenn gerade die Seitenleiste den Fokus hat: weiter an das Terminal.
    override func performTextFinderAction(_ sender: Any?) {
        guard let terminal else { return }
        window?.makeFirstResponder(terminal)
        terminal.performTextFinderAction(sender)
    }

    private func functionKey(_ number: Int) {
        switch number {
        case 1: clearScreenAndHistory(nil)
        case 2: copyEverything(nil)
        case 3: duplicateConnection(nil)
        case 4: changeTitle(nil)
        default: break
        }
    }

    // MARK: - Einfügen mit Rückfrage (S10)

    /// Ohne Zeilenumbruch sofort; sonst erst nach Bestätigung in der Hinweisleiste. SwiftTerm schickt eingefügten Text
    /// als Bracketed Paste, wenn das Programm es eingeschaltet hat, und ersetzt Steuerzeichen (z. B. ESC) durch Leerzeichen.
    func requestPaste(_ text: String) {
        guard let terminal, isConnected, pendingPaste == nil, !text.isEmpty else { return }
        let lines: Int = PasteCheck.linesNeedingConfirmation(in: text)
        guard lines > 0 else {
            terminal.pasteText(text)
            return
        }
        pendingPaste = text
        terminal.isPastePending = true
        let banner: PasteBanner = PasteBanner(lines: lines) { [weak self] insert in self?.finishPaste(insert) }
        let view: NSHostingView<PasteBanner> = NSHostingView(rootView: banner)
        view.sizingOptions = [.intrinsicContentSize]
        area.showBanner(view)
        window?.makeFirstResponder(terminal)   // Esc und ⌘↩ wirken nur im Terminal (z. B. nach Rechtsklick aus einem Feld)
        NSAccessibility.post(element: window as Any, notification: .announcementRequested,
                             userInfo: [.announcement: banner.message + " Escape bricht ab, Befehl-Return fügt ein.",
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    var isPastePending: Bool { pendingPaste != nil }

    func finishPaste(_ insert: Bool) {
        guard let text = pendingPaste else { return }
        pendingPaste = nil
        terminal?.isPastePending = false
        area.showBanner(nil)
        if let terminal {
            window?.makeFirstResponder(terminal)
            if insert && isConnected { terminal.pasteText(text) }
        }
    }

    // MARK: - Menübefehle: Sitzungen

    @objc func newSession(_ sender: Any?) { sessions.newSession() }

    @objc func editSession(_ sender: Any?) { sessions.editSelection() }

    @objc func duplicateSessions(_ sender: Any?) { sessions.duplicateSelection() }

    @objc func deleteSessions(_ sender: Any?) { sessions.deleteSelection() }

    @objc func connectSessions(_ sender: Any?) { sessions.connect(sessions.selection) }

    /// Registrierungsdatei (`.reg`) aus Windows-PuTTY.
    @objc func importRegistry(_ sender: Any?) {
        let panel: NSOpenPanel = NSOpenPanel()
        panel.message = "Registrierungsdatei (.reg) aus Windows-PuTTY wählen (regedit: Export von HKEY_CURRENT_USER\\Software\\SimonTatham)"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [Self.registryType]
        runImportPanel(panel, startingIn: FileManager.default.homeDirectoryForCurrentUser)
    }

    /// PuTTY-Ordner von PuTTY für macOS/Linux (`~/.config/putty`, `~/.putty`). Eine Auswahl „Datei oder Ordner“ in einem
    /// Dialog geht nicht: NSOpenPanel öffnet einen markierten Ordner dann, statt ihn zu wählen.
    @objc func importFolder(_ sender: Any?) {
        let panel: NSOpenPanel = NSOpenPanel()
        panel.message = "PuTTY-Ordner wählen (enthält den Unterordner „sessions“, z. B. ~/.config/putty)"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        let home: URL = FileManager.default.homeDirectoryForCurrentUser
        let known: URL? = [".config/putty", ".putty"].map { home.appendingPathComponent($0, isDirectory: true) }
            .first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("sessions").path) }
        runImportPanel(panel, startingIn: known ?? home)
    }

    private func runImportPanel(_ panel: NSOpenPanel, startingIn directory: URL) {
        guard let window else { return }
        panel.prompt = "Importieren"
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true   // ~/.config und ~/.putty sind versteckt
        panel.directoryURL = directory
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.sessions.prepareImport(from: url)
        }
    }

    @objc func exportRegistry(_ sender: Any?) {
        guard let window else { return }
        let names: [String] = exportNames
        let panel: NSSavePanel = NSSavePanel()
        panel.message = "Für Windows-PuTTY: Datei doppelklicken oder mit regedit importieren"
        panel.nameFieldStringValue = "PuTTY-Sitzungen.reg"
        panel.allowedContentTypes = [Self.registryType]
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                try self.sessions.library.writeRegistryExport(of: names, to: url)
            } catch {
                self.sessions.report(error)
            }
        }
    }

    @objc func exportFolder(_ sender: Any?) {
        guard let window else { return }
        let names: [String] = exportNames
        let panel: NSSavePanel = NSSavePanel()
        panel.message = "Für PuTTY unter macOS oder Linux: Ordner als ~/.config/putty verwenden oder dorthin kopieren"
        panel.nameFieldStringValue = "putty"
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                try self.sessions.library.exportFolder(of: names, to: url)
            } catch {
                self.sessions.report(error)
            }
        }
    }

    /// Ausgewählte Sitzungen, ohne Auswahl alle.
    private var exportNames: [String] {
        sessions.savedSelection.isEmpty ? sessions.library.names : sessions.savedSelection
    }

    /// ⌘⌫ löscht Sitzungen nur, wenn die Sitzungsliste selbst den Fokus hat – im Terminal, in Textfeldern und auf
    /// anderen Bedienelementen gehört die Taste dorthin. Bei offenem Sheet (Editor) zeigt `firstResponder` noch die
    /// Liste, obwohl im Sheet getippt wird.
    private var sessionListHasFocus: Bool {
        guard let window, window.attachedSheet == nil,
              let list = window.firstResponder as? NSTableView else { return false }   // SwiftUI-List ist eine Tabelle
        return list.isDescendant(of: sidebarItem.viewController.view)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Bei offenem Sheet (Editor, Rückfrage, Dialog) erreichen Menübefehle dieses Fenster weiter über das Hauptfenster:
        // nur Trennen bleibt
        if window?.attachedSheet != nil { return menuItem.action == #selector(disconnect(_:)) && isConnected }
        return switch menuItem.action {
        case #selector(reconnect(_:)): connection.map { !$0.isRunning } ?? false
        case #selector(disconnect(_:)): isConnected
        case #selector(deleteSessions(_:)): sessionListHasFocus && !sessions.savedSelection.isEmpty
        case #selector(duplicateSessions(_:)):
            !sessions.savedSelection.contains(SessionName.defaultSettings) && !sessions.savedSelection.isEmpty
        case #selector(editSession(_:)): sessions.selection.count == 1
        case #selector(connectSessions(_:)): !sessions.connectableSelection.isEmpty
        case #selector(exportRegistry(_:)), #selector(exportFolder(_:)): !sessions.library.names.isEmpty
        case #selector(clearScreenAndHistory(_:)), #selector(copyEverything(_:)),
             #selector(performTextFinderAction(_:)): terminal != nil
        case #selector(duplicateConnection(_:)): connection != nil
        case #selector(editTunnels(_:)): canEditTunnels
        default: true
        }
    }

    // MARK: - Symbolleiste

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace, Self.tunnelItem, Self.disconnectItem,
         .inspectorTrackingSeparator, .flexibleSpace, .toggleInspector]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item: NSToolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        switch itemIdentifier {
        case Self.disconnectItem:
            item.label = "Trennen"
            item.toolTip = "Verbindung trennen (⌘.)"
            item.image = NSImage(systemSymbolName: "bolt.horizontal.circle", accessibilityDescription: "Trennen")
            item.action = #selector(disconnect(_:))
        case Self.tunnelItem:
            item.label = "Tunnel"
            item.toolTip = "Port-Weiterleitungen dieser Sitzung bearbeiten"
            item.image = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted", accessibilityDescription: "Tunnel")
            item.action = #selector(editTunnels(_:))
        default:
            return nil
        }
        return item
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case Self.disconnectItem: isConnected
        case Self.tunnelItem: window?.attachedSheet == nil && canEditTunnels
        default: true
        }
    }

    // MARK: - Fenster

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard isConnected, !closingConfirmed, let connection else { return true }
        let alert: NSAlert = NSAlert()
        alert.messageText = "Verbindung zu „\(SessionWarning.visible(connection.displayName))“ trennen?"
        alert.informativeText = "Die laufende Sitzung wird beendet."
        alert.addButton(withTitle: "Trennen").hasDestructiveAction = true
        alert.addButton(withTitle: "Abbrechen")
        alert.beginSheetModal(for: sender) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            self.closingConfirmed = true
            sender.close()
        }
        return false
    }

    func windowWillClose(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        connection?.hangUp()
        releaseCountedSession()
        onClose?(self)
    }

    // MARK: - TerminalViewDelegate

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        connection?.send(data)
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        connection?.resize(columns: newCols, rows: newRows)
        info.columns = newCols
        info.rows = newRows
    }

    /// Titel vom Server werden nicht übernommen: Der Fenstertitel ist die Adresse bzw. der Sitzungsname (Plan M1/M2).
    func setTerminalTitle(source: TerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func scrolled(source: TerminalView, position: Double) {}
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

    /// OSC 52: Der Server will Text in die Zwischenablage legen – nur nach Rückfrage mit Vorschau (S11). Läuft schon eine
    /// Rückfrage, wird die Anfrage verworfen (ein Server kann sie in Schleife schicken).
    func clipboardCopy(source: TerminalView, content: Data) {
        guard let window, window.attachedSheet == nil, !clipboardRefused, content.count <= Self.clipboardLimit,
              let text = String(data: content, encoding: .utf8), !text.isEmpty else { return }
        let alert: NSAlert = NSAlert()
        alert.messageText = "Der Server möchte Text in die Zwischenablage legen."
        alert.informativeText = "\(text.count) Zeichen:\n\n" + Self.preview(text)
        alert.addButton(withTitle: "Nicht erlauben")
        alert.addButton(withTitle: "In die Zwischenablage")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertSecondButtonReturn else {
                self?.clipboardRefused = true
                return
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    /// Lesen der Zwischenablage (OSC 52) bleibt verboten: Die Frage käme mitten aus der Ausgabe, eine Antwort ginge
    /// an den Server (S11).
    func clipboardRead(source: TerminalView) -> Data? { nil }

    /// Links (OSC 8 oder erkannte Adressen, ⌘-Klick): nur http, https und mailto, immer mit Rückfrage und voller
    /// Adresse (S11).
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        guard let window, window.attachedSheet == nil else { return }
        let alert: NSAlert = NSAlert()
        guard let url = LinkPolicy.openableURL(link) else {
            alert.messageText = "Dieser Link wird nicht geöffnet."
            alert.informativeText = "Aus dem Terminal öffnet \(AppIdentity.name) nur Web- und E-Mail-Adressen "
                + "(http, https, mailto):\n\n" + Self.preview(link)
            alert.beginSheetModal(for: window)
            return
        }
        alert.messageText = "Link aus dem Terminal öffnen?"
        // Ziel eigens nennen: in „https://bank.example@boese.test“ ist boese.test das Ziel (Prüfer-Befund 10)
        let target: String = url.host.map { "Ziel: \(SessionWarning.visible($0))\n\n" } ?? ""
        alert.informativeText = target + SessionWarning.visible(url.absoluteString) + "\n\nDer Link kommt vom Server bzw. "
            + "aus der Ausgabe eines Programms."
        alert.addButton(withTitle: "Abbrechen")
        alert.addButton(withTitle: "Öffnen")
        alert.beginSheetModal(for: window) { response in
            if response == .alertSecondButtonReturn { NSWorkspace.shared.open(url) }
        }
    }

    /// Größte Datenmenge, die ein Server per OSC 52 in die Zwischenablage legen darf (1 MiB).
    static let clipboardLimit: Int = 1 << 20

    /// Kurze, sichtbare Vorschau: höchstens 10 Zeilen und 400 Zeichen, Steuerzeichen als `\u{…}`.
    static func preview(_ text: String) -> String {
        let all: [Substring] = text.split(separator: "\n", omittingEmptySubsequences: false)
        let shown: String = all.prefix(10).map { SessionWarning.visible(String($0)) }.joined(separator: "\n")
        let short: String = String(shown.prefix(400))
        return all.count > 10 || short.count < shown.count ? short + " …" : short
    }

}

private extension Error {
    /// Text für Feld und Hinweis.
    var message: String {
        switch self {
        case let error as InputError: error.message
        case let error as TerminalProcess.Failure: error.message
        default: localizedDescription
        }
    }
}
