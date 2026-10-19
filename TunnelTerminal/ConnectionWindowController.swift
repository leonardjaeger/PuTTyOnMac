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
    private let info: ConnectionInfo = ConnectionInfo()
    private let split: NSSplitViewController = NSSplitViewController()
    private let sidebarItem: NSSplitViewItem
    private let inspectorItem: NSSplitViewItem
    private let area: TerminalArea = TerminalArea()

    private var connection: Connection?
    private var terminal: TerminalView?
    /// Gespeicherte Sitzung, die für den Status in der Seitenleiste als verbunden zählt.
    private var countedSession: String?
    private var closingConfirmed: Bool = false
    /// Server und Port, deren bekannte Hostschlüssel der Inspektor zeigt (nur SSH, M3).
    private var hostKeyServer: (host: String, port: Int)?
    private var lastHostKeyCheck: Date = .distantPast

    private static let registryType: UTType = UTType(filenameExtension: "reg") ?? .data
    private static let disconnectItem: NSToolbarItem.Identifier = NSToolbarItem.Identifier("trennen")

    var isConnected: Bool { connection?.isRunning ?? false }
    var showsSidebar: Bool { !sidebarItem.isCollapsed }
    var showsInspector: Bool { !inspectorItem.isCollapsed }

    /// Adresse und Protokoll der Verbindung dieses Tabs (zum Vorbelegen eines neuen Tabs).
    var address: (text: String, connectionProtocol: ConnectionProtocol)? {
        connection?.quickAddress
    }

    init(library: SessionLibrary, connected: ConnectedSessions, address: String = "",
         connectionProtocol: ConnectionProtocol = .ssh, showsSidebar: Bool = true, showsInspector: Bool = true) {
        sessions = SessionsModel(library: library)
        quick = QuickConnect(address: address, connectionProtocol: connectionProtocol)
        self.connected = connected

        let sidebar: NSHostingController<SessionSidebar> = NSHostingController(
            rootView: SessionSidebar(model: sessions, quick: quick, connected: connected))
        sidebar.sizingOptions = []   // keine Größenbindung an den SwiftUI-Inhalt (Richtlinien 3.4 Regel 19)
        sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 210
        sidebarItem.maximumThickness = 360
        sidebarItem.isCollapsed = !showsSidebar

        let content: NSSplitViewItem = NSSplitViewItem(viewController: area)
        content.minimumThickness = 360

        let inspector: NSHostingController<ConnectionInspector> = NSHostingController(rootView: ConnectionInspector(info: info))
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
            connectionEnded("Nicht verbunden: Die Sitzung ist nicht lesbar (\(error.message))")
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
        connection = newConnection
        window?.title = SessionWarning.visible(newConnection.displayName)
        let settings: SessionFile? = newConnection.settings()
        info.summary = settings.map(ConnectionSummary.init(file:))
        info.hasStoredPassword = newConnection.hasStoredPassword
        hostKeyServer = settings?.hostKeyServer
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
        if hostKeyServer != nil, info.hostKeys.isEmpty, Date.now.timeIntervalSince(lastHostKeyCheck) >= 1 { refreshHostKeys() }
    }

    private func showTerminal() {
        guard terminal == nil else { return }
        let view: TerminalView = TerminalView(frame: area.view.bounds)
        view.terminalDelegate = self
        view.setAccessibilityLabel("Terminal")
        area.show(view)
        window?.makeFirstResponder(view)
        window?.layoutIfNeeded()
        terminal = view
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
        info.endMessage = nil
        info.hasStoredPassword = newConnection.usesStoredPassword
        if case .saved(let name) = newConnection.target {
            connected.started(name)
            countedSession = name
        }
    }

    private func connectionEnded(_ message: String) {
        releaseCountedSession()
        info.isRunning = false
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

    /// ⇧⌘K: Fokus in die Schnellverbindung (blendet die Seitenleiste ein).
    @objc func focusQuickConnect(_ sender: Any?) {
        sidebarItem.isCollapsed = false
        quick.requestFocus()
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
        default: true
        }
    }

    // MARK: - Symbolleiste

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace, Self.disconnectItem,
         .inspectorTrackingSeparator, .flexibleSpace, .toggleInspector]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard itemIdentifier == Self.disconnectItem else { return nil }
        let item: NSToolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "Trennen"
        item.toolTip = "Verbindung trennen (⌘.)"
        item.image = NSImage(systemSymbolName: "bolt.horizontal.circle", accessibilityDescription: "Trennen")
        item.action = #selector(disconnect(_:))
        return item
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        item.itemIdentifier == Self.disconnectItem ? isConnected : true
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
    }

    /// Titel vom Server werden nicht übernommen: Der Fenstertitel ist die Adresse bzw. der Sitzungsname (Plan M1/M2).
    func setTerminalTitle(source: TerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func scrolled(source: TerminalView, position: Double) {}
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

    /// OSC 52 und Links aus der Ausgabe werden abgelehnt (S11; Rückfrage folgt in M4).
    func clipboardCopy(source: TerminalView, content: Data) {}
    func clipboardRead(source: TerminalView) -> Data? { nil }
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
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
