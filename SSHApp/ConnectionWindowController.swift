import AppKit
import SSHAppCore
import SwiftTerm
import SwiftUI

/// Ein Fenster bzw. Tab: zuerst die Schnellverbindung, danach das Terminal der Verbindung.
final class ConnectionWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation, TerminalViewDelegate {
    /// Gemeinsame Kennung, damit macOS die Fenster zu Tabs zusammenfasst.
    static let tabbingIdentifier: String = "Verbindung"

    var onClose: ((ConnectionWindowController) -> Void)?

    private var connection: Connection?
    private var terminal: TerminalView?
    private var banner: NSTitlebarAccessoryViewController?
    private var closingConfirmed: Bool = false

    var isConnected: Bool { connection?.isRunning ?? false }

    /// Adresse und Protokoll der Verbindung dieses Tabs (zum Vorbelegen eines neuen Tabs).
    var address: (text: String, connectionProtocol: ConnectionProtocol)? {
        connection.map { ($0.endpoint.displayName, $0.connectionProtocol) }
    }

    init(address: String = "", connectionProtocol: ConnectionProtocol = .ssh) {
        let window: NSWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 540),
                                        styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                        backing: .buffered, defer: false)
        window.title = "Neue Verbindung"
        window.tabbingIdentifier = Self.tabbingIdentifier
        window.isRestorable = false
        window.minSize = NSSize(width: 420, height: 240)
        super.init(window: window)
        window.delegate = self
        showForm(address: address, connectionProtocol: connectionProtocol)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht benutzt") }

    // MARK: - Ablauf

    private func showForm(address: String, connectionProtocol: ConnectionProtocol) {
        let rootView: ConnectForm = ConnectForm(address: address, connectionProtocol: connectionProtocol) { [weak self] text, choice in
            self?.connect(address: text, using: choice)
        }
        let form: NSHostingView<ConnectForm> = NSHostingView(rootView: rootView)
        form.sizingOptions = []   // keine Größenbindung des Fensters an das Formular (Richtlinien 3.4 Regel 19)
        window?.contentView = form
    }

    /// Prüft die Adresse und startet die Verbindung. Gibt eine Fehlermeldung für das Formular zurück.
    private func connect(address: String, using choice: ConnectionProtocol) -> String? {
        let newConnection: Connection
        do {
            newConnection = try Connection(endpoint: try Endpoint(parsing: address), connectionProtocol: choice)
        } catch {
            return error.message
        }
        showTerminal()
        start(newConnection)
        return nil
    }

    private func showTerminal() {
        guard terminal == nil, let window else { return }
        let view: TerminalView = TerminalView(frame: window.contentLayoutRect)
        view.terminalDelegate = self
        view.setAccessibilityLabel("Terminal")
        window.contentView = view
        window.makeFirstResponder(view)
        window.layoutIfNeeded()
        terminal = view
    }

    private func start(_ newConnection: Connection) {
        guard let terminal else { return }
        connection = newConnection
        window?.title = newConnection.endpoint.displayName
        newConnection.onOutput = { [weak terminal] bytes in terminal?.feed(byteArray: bytes) }
        newConnection.onEnd = { [weak self] message in self?.connectionEnded(message) }
        let size: TerminalDimensions = terminal.terminalDimensions
        do {
            try newConnection.start(columns: size.cols, rows: size.rows)
        } catch {
            AppLog.connection.error("Start fehlgeschlagen")
            connectionEnded(error.message)
        }
    }

    private func connectionEnded(_ message: String) {
        showBanner(message)
        NSAccessibility.post(element: window as Any, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    private func showBanner(_ message: String) {
        removeBanner()
        let accessory: NSTitlebarAccessoryViewController = NSTitlebarAccessoryViewController()
        let content: NSHostingView<EndedBanner> = NSHostingView(rootView: EndedBanner(message: message) { [weak self] in
            self?.reconnect(nil)
        })
        content.sizingOptions = [.intrinsicContentSize]
        accessory.view = content
        accessory.layoutAttribute = .bottom
        window?.addTitlebarAccessoryViewController(accessory)
        banner = accessory
    }

    private func removeBanner() {
        banner?.removeFromParent()
        banner = nil
    }

    // MARK: - Menübefehle

    @objc func reconnect(_ sender: Any?) {
        guard let previous = connection, !previous.isRunning else { return }
        removeBanner()
        terminal?.feed(text: "\r\n")
        do {
            start(try Connection(endpoint: previous.endpoint, connectionProtocol: previous.connectionProtocol))
        } catch {
            connectionEnded(error.message)
        }
    }

    @objc func disconnect(_ sender: Any?) {
        connection?.hangUp()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(reconnect(_:)): connection.map { !$0.isRunning } ?? false
        case #selector(disconnect(_:)): isConnected
        default: true
        }
    }

    // MARK: - Fenster

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard isConnected, !closingConfirmed, let connection else { return true }
        let alert: NSAlert = NSAlert()
        alert.messageText = "Verbindung zu „\(connection.endpoint.displayName)“ trennen?"
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
        onClose?(self)
    }

    // MARK: - TerminalViewDelegate

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        connection?.send(data)
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        connection?.resize(columns: newCols, rows: newRows)
    }

    /// Titel vom Server werden nicht übernommen: Der Fenstertitel ist die Adresse (Plan M1).
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
    /// Text für Formular und Hinweis.
    var message: String {
        switch self {
        case let error as InputError: error.message
        case let error as TerminalProcess.Failure: error.message
        default: localizedDescription
        }
    }
}
