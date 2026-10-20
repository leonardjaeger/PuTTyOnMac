import AppKit
import TunnelTerminalCore
import SwiftTerm
import SwiftUI

/// Hauptfenster bzw. ein Tab, Gerüst B „Werkbank“ (Plan 3.1): links die Seitenleiste mit Schnellverbindung und
/// Sitzungen, in der Mitte Startansicht bzw. Terminal, rechts der Inspektor. Menübefehle zu Sitzungen und zur
/// Verbindung landen hier über die Responder-Kette.
final class ConnectionWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation,
    NSToolbarItemValidation, TerminalViewDelegate {
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
    private let toolbarDelegate: WorkbenchToolbar = WorkbenchToolbar()
    /// Dateiübertragung dieses Tabs (M6).
    private let transfers: FileTransferController = FileTransferController()

    private var connection: Connection?
    private(set) var terminal: AppTerminalView?
    /// Eigener Titel des Tabs („Titel ändern …“, M4); `nil` = Adresse bzw. Sitzungsname.
    private var customTitle: String?
    /// Text, der auf die Bestätigung in der Hinweisleiste wartet (S10).
    private var pendingPaste: String?
    /// Tasten vor SwiftTerm: Hinweisleiste (Esc, ⌘↩) und F1–F4 (`AppTerminalView.handleKey`).
    private var keyMonitor: Any?
    /// Wünsche des Servers aus der Ausgabe: Zwischenablage (OSC 52) und Links, nur mit Rückfrage (S11).
    private let serverRequests: ServerRequestPrompts = ServerRequestPrompts()
    /// Gespeicherte Sitzung, die für den Status in der Seitenleiste als verbunden zählt.
    private var countedSession: String?
    private var closingConfirmed: Bool = false
    /// Server und Port, deren bekannte Hostschlüssel der Inspektor zeigt (nur SSH, M3).
    private var hostKeyServer: (host: String, port: Int)?
    private var lastHostKeyCheck: Date = .distantPast
    /// Seriell: Das Gerät ist mit dem Start offen und schweigt oft, bis man tippt (kein „Verbinde …“ bis zur Ausgabe).
    private var opensInstantly: Bool = false


    var isConnected: Bool { connection?.isRunning ?? false }
    var isTransferring: Bool { transfers.isRunning }
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
        sidebarItem.minimumThickness = 240   // „Standardeinstellungen“ ungekürzt (M7); 240 + 360 + 220 = Mindestbreite 820
        sidebarItem.maximumThickness = 360
        sidebarItem.isCollapsed = !showsSidebar

        let content: NSSplitViewItem = NSSplitViewItem(viewController: area)
        content.minimumThickness = 360

        let inspector: NSHostingController<ConnectionInspector> = NSHostingController(
            rootView: ConnectionInspector(info: info, profiles: profiles, transfers: transfers.model))
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
        toolbar.delegate = toolbarDelegate
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
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
        transfers.window = { [weak self] in self?.window }
        transfers.connection = { [weak self] in self?.connection }
        transfers.model.upload = { [weak self] urls in
            guard let self, canTransfer else { return }
            transfers.upload(urls)
        }
        transfers.model.chooseFiles = { [weak self] in self?.uploadFiles(nil) }
        transfers.model.download = { [weak self] in self?.downloadFile(nil) }
        transfers.model.cancel = { [weak self] in self?.cancelTransfer(nil) }
        transfers.revealInspector = { [weak self] in self?.inspectorItem.isCollapsed = false }
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
        serverRequests.reset()
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
        // Dateien aufs Terminal ziehen lädt sie hoch (M6); SwiftTerm selbst nimmt keine Dateien an
        view.registerForDraggedTypes([.fileURL])
        view.acceptsFiles = { [weak self] in self?.canTransfer ?? false }
        view.onDropFiles = { [weak self] urls in self?.transfers.upload(urls) }
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

    // MARK: - Menübefehle: Dateien (M6)

    /// Symbolleiste „Hochladen“, Verbindung › Datei hochladen …, Klick auf die Ablagefläche im Inspektor.
    @objc func uploadFiles(_ sender: Any?) {
        guard let window, canTransfer else { return }
        let panel: NSOpenPanel = NSOpenPanel()
        panel.message = "Dateien zum Hochladen wählen – den Zielordner auf dem Server wählst du danach"
        panel.prompt = "Weiter …"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            self?.transfers.upload(panel.urls)
        }
    }

    @objc func downloadFile(_ sender: Any?) {
        guard canTransfer else { return }
        transfers.download()
    }

    @objc func cancelTransfer(_ sender: Any?) {
        transfers.cancel()
    }

    /// Verbundener SSH-Tab (Plan M6: „in einem verbundenen Fenster“; pscp spricht nur SSH) ohne offenes Sheet und ohne
    /// laufende Übertragung.
    private var canTransfer: Bool {
        isConnected && info.summary?.showsTunnels == true && window?.attachedSheet == nil && !transfers.isRunning
    }

    /// Gespeicherte SSH-Sitzung im Tab (nur dort wirken Weiterleitungen).
    private var canEditTunnels: Bool { info.editableSession != nil && info.summary?.showsTunnels == true }

    private func savedSessionName(of connection: Connection) -> String? {
        if case .saved(let name) = connection.target { name } else { nil }
    }

    // MARK: - Links aus anderen Apps (M7, S6)

    /// `ssh://` bzw. `telnet://` aus einer anderen App: Rückfrage am Fenster (`AppLinkPrompt`), dann in diesem Tab, wenn
    /// er frei ist, sonst in einem neuen daneben. `done` läuft, sobald die Rückfrage geschlossen ist.
    func openLink(_ text: String, defaults: UserDefaults = .standard, done: @escaping () -> Void = {}) {
        AppLinkPrompt.show(text, defaults: defaults, in: window, done: done) { [weak self] link in
            guard let self else { return }
            do {
                request(.connection(try Connection(endpoint: link.endpoint, connectionProtocol: link.connectionProtocol,
                                                   puttyDirectory: puttyDirectory)))
            } catch {
                sessions.report(error)
            }
        }
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

    /// ⌘⌫ löscht Sitzungen nur, wenn die Sitzungsliste selbst den Fokus hat – im Terminal, in Textfeldern und auf
    /// anderen Bedienelementen gehört die Taste dorthin. Bei offenem Sheet (Editor) zeigt `firstResponder` noch die
    /// Liste, obwohl im Sheet getippt wird.
    private var sessionListHasFocus: Bool {
        guard let window, window.attachedSheet == nil,
              let list = window.firstResponder as? NSTableView else { return false }   // SwiftUI-List ist eine Tabelle
        return list.isDescendant(of: sidebarItem.viewController.view)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        commandState.allows(menuItem.action)
    }

    /// Die Knöpfe haben dieselben Aktionen wie die Menübefehle, also gelten dieselben Regeln.
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        commandState.allows(item.action)
    }

    /// Zustand für Menü und Symbolleiste; die Regeln stehen in `TabCommandState` (M7 aus diesem Controller gelöst).
    private var commandState: TabCommandState {
        TabCommandState(hasSheet: window?.attachedSheet != nil, isConnected: isConnected, hasConnection: connection != nil,
                        hasTerminal: terminal != nil, canTransfer: canTransfer,
                        canEditTunnels: canEditTunnels, isTransferring: transfers.isRunning,
                        sessionListHasFocus: sessionListHasFocus, savedSelection: sessions.savedSelection,
                        selectionCount: sessions.selection.count,
                        hasConnectableSelection: !sessions.connectableSelection.isEmpty,
                        hasSavedSessions: !sessions.library.names.isEmpty)
    }

    // MARK: - Fenster

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard isConnected || isTransferring, !closingConfirmed, let connection else { return true }
        let alert: NSAlert = NSAlert()
        if isConnected {
            alert.messageText = "Verbindung zu „\(SessionWarning.visible(connection.displayName))“ trennen?"
            alert.informativeText = isTransferring ? "Die laufende Sitzung und die Dateiübertragung werden beendet."
                : "Die laufende Sitzung wird beendet."
        } else {
            alert.messageText = "Dateiübertragung beenden?"
            alert.informativeText = "Das Fenster schließt, die laufende Übertragung wird abgebrochen."
        }
        alert.addButton(withTitle: isConnected ? "Trennen" : "Übertragung beenden").hasDestructiveAction = true
        alert.addButton(withTitle: isConnected ? "Abbrechen" : "Weiter übertragen")
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
        transfers.cancel()
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

    /// OSC 52: Der Server will Text in die Zwischenablage legen – nur nach Rückfrage (S11).
    func clipboardCopy(source: TerminalView, content: Data) {
        serverRequests.clipboardCopy(content, in: window)
    }

    /// Lesen der Zwischenablage (OSC 52) bleibt verboten: Die Frage käme mitten aus der Ausgabe, eine Antwort ginge
    /// an den Server (S11).
    func clipboardRead(source: TerminalView) -> Data? { nil }

    /// Links (OSC 8 oder erkannte Adressen, ⌘-Klick): nur http, https und mailto, immer mit Rückfrage (S11).
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        serverRequests.openLink(link, in: window)
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
