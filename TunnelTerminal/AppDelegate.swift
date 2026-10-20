import AppKit
import TunnelTerminalCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controllers: [ConnectionWindowController] = []
    /// Gespeicherte Sitzungen, gemeinsam für alle Fenster.
    private var library: SessionLibrary?
    private let connected: ConnectedSessions = ConnectedSessions()
    /// Fenster „Schlüssel“ und „Bekannte Hostschlüssel“, je eines für die App (M3).
    private var keysWindow: ToolWindowController?
    private var knownHostsWindow: ToolWindowController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build()
        removeQuickSessions()   // Reste nach einem Absturz
        do {
            library = SessionLibrary(directory: try AppIdentity.puttyDirectory(), passwords: AppIdentity.passwords)
        } catch {
            AppLog.app.error("PuTTY-Ordner nicht erreichbar: \(error.localizedDescription, privacy: .private(mask: .hash))")
            NSAlert(error: error).runModal()   // ohne PuTTY-Ordner geht weder Sitzung noch Schnellverbindung
            NSApp.terminate(nil)
            return
        }
        newWindow(nil)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { newWindow(nil) }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let running: Int = controllers.count(where: { $0.isConnected })
        guard running > 0 else { return .terminateNow }
        let alert: NSAlert = NSAlert()
        alert.messageText = "\(AppIdentity.name) beenden?"
        alert.informativeText = running == 1
            ? "Eine Verbindung ist noch aktiv und wird getrennt."
            : "\(running) Verbindungen sind noch aktiv und werden getrennt."
        alert.addButton(withTitle: "Beenden").hasDestructiveAction = true
        alert.addButton(withTitle: "Abbrechen")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        for controller in controllers { controller.disconnect(nil) }
        removeQuickSessions()   // plink hat die Sitzungen beim Start gelesen
    }

    @objc func newWindow(_ sender: Any?) {
        let controller: ConnectionWindowController? = makeController()
        controller?.quick.requestFocus()
        controller?.showWindow(nil)
    }

    // Ohne Fenster landen diese Befehle hier (kein Fenster-Controller in der Responder-Kette): Fenster öffnen und
    // weiterreichen.
    @objc func newSession(_ sender: Any?) { frontController()?.newSession(nil) }
    @objc func importRegistry(_ sender: Any?) { frontController()?.importRegistry(nil) }
    @objc func importFolder(_ sender: Any?) { frontController()?.importFolder(nil) }
    @objc func focusQuickConnect(_ sender: Any?) { frontController()?.focusQuickConnect(nil) }

    /// Fenster „Schlüssel“ (Seitenleiste unten, Fenster-Menü, Hilfe).
    @objc func showKeys(_ sender: Any?) {
        if keysWindow == nil {
            let model: KeysModel = KeysModel()
            let controller: ToolWindowController = ToolWindowController(title: "Schlüssel", autosaveName: "Schlüssel",
                                                                        rootView: KeysView(model: model))
            model.window = controller.window
            keysWindow = controller
        }
        keysWindow?.showWindow(nil)
    }

    /// Einstellungen (⌘,), ein Fenster für die App.
    @objc func showSettings(_ sender: Any?) {
        if settingsWindow == nil { settingsWindow = SettingsWindowController(profiles: AppIdentity.profiles) }
        settingsWindow?.showWindow(nil)
    }

    /// Fenster „Bekannte Hostschlüssel“; liest die Liste neu, sobald es nach vorne kommt.
    @objc func showKnownHosts(_ sender: Any?) {
        guard let library else { return }
        if knownHostsWindow == nil {
            let model: KnownHostsModel = KnownHostsModel(directory: library.directory)
            let controller: ToolWindowController = ToolWindowController(
                title: "Bekannte Hostschlüssel", autosaveName: "Bekannte Hostschlüssel", rootView: KnownHostsView(model: model))
            controller.onBecomeKey = { [weak model] in model?.reload() }
            model.reload()
            knownHostsWindow = controller
        }
        knownHostsWindow?.showWindow(nil)
    }

    private func frontController() -> ConnectionWindowController? {
        let controller: ConnectionWindowController? = makeController()
        controller?.showWindow(nil)
        return controller
    }

    /// ⌘T und „+“ in der Tab-Leiste: neuer Tab, Schnellverbindung vorbelegt mit der Adresse des aktiven Tabs.
    @objc func newWindowForTab(_ sender: Any?) {
        let current: ConnectionWindowController? = keyController
        guard let controller = makeController(address: current?.address, like: current),
              let tabWindow = controller.window else { return }
        controller.quick.requestFocus()   // nur hier und bei neuen Fenstern: ein Tab mit Verbindung behält den Terminal-Fokus
        current?.window?.addTabbedWindow(tabWindow, ordered: .above)
        tabWindow.makeKeyAndOrderFront(nil)
    }

    /// Verbindung aus der Seitenleiste eines schon verbundenen Tabs: neuer Tab daneben.
    private func open(_ opening: ConnectionWindowController.Opening, nextTo current: ConnectionWindowController) {
        guard let controller = makeController(like: current), let tabWindow = controller.window else { return }
        current.window?.addTabbedWindow(tabWindow, ordered: .above)
        tabWindow.makeKeyAndOrderFront(nil)
        controller.open(opening)
    }

    private var keyController: ConnectionWindowController? {
        controllers.first { $0.window === NSApp.keyWindow }
    }

    /// Neues Fenster bzw. neuer Tab; Seitenleiste und Inspektor wie im aktiven Fenster.
    private func makeController(address: (text: String, connectionProtocol: ConnectionProtocol)? = nil,
                                like model: ConnectionWindowController? = nil) -> ConnectionWindowController? {
        guard let library else { return nil }
        library.reload()   // Sitzungen, die eine andere PuTTY-Installation inzwischen angelegt hat
        let template: ConnectionWindowController? = model ?? keyController
        let controller: ConnectionWindowController = ConnectionWindowController(
            library: library, connected: connected, address: address?.text ?? "",
            connectionProtocol: address?.connectionProtocol ?? .ssh,
            showsSidebar: template?.showsSidebar ?? true, showsInspector: template?.showsInspector ?? true)
        controller.onClose = { [weak self] closed in self?.controllers.removeAll { $0 === closed } }
        controller.onOpenInNewTab = { [weak self] opening, current in self?.open(opening, nextTo: current) }
        controllers.append(controller)
        return controller
    }

    private func removeQuickSessions() {
        do {
            try AppIdentity.puttyDirectory().removeSessions(withPrefix: AppIdentity.quickSessionPrefix)
        } catch {
            AppLog.app.error("PuTTY-Ordner nicht erreichbar: \(error.localizedDescription, privacy: .private(mask: .hash))")
        }
    }
}
