import AppKit
import SwiftUI
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
    /// Hilfe-Fenster (M7), je eines für die App.
    private var shortcutsWindow: ToolWindowController?
    private var quickStartWindow: QuickStartWindowController?
    /// Link, der vor dem Ende des Starts ankam (M7).
    private var pendingLink: String?
    /// Eine Link-Rückfrage ist offen: weitere Links verwerfen, statt Fenster um Fenster zu öffnen (S6).
    /// Fenster mit der offenen Link-Rückfrage: sperrt weitere Links, bis sie zu ist (oder ihr Fenster geschlossen wurde).
    private weak var linkPromptWindow: NSWindow?

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
        if let pendingLink {
            self.pendingLink = nil
            openLink(pendingLink)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { newWindow(nil) }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let running: Int = controllers.count(where: { $0.isConnected })
        let transferring: Int = controllers.count(where: { $0.isTransferring })
        guard running + transferring > 0 else { return .terminateNow }
        let alert: NSAlert = NSAlert()
        alert.messageText = "\(AppIdentity.name) beenden?"
        let connections: String = running == 1 ? "Eine Verbindung ist noch aktiv und wird getrennt."
            : "\(running) Verbindungen sind noch aktiv und werden getrennt."
        let transfers: String = transferring == 1 ? "Eine Dateiübertragung läuft und wird abgebrochen."
            : "\(transferring) Dateiübertragungen laufen und werden abgebrochen."
        alert.informativeText = [running > 0 ? connections : nil, transferring > 0 ? transfers : nil]
            .compactMap { $0 }.joined(separator: " ")
        alert.addButton(withTitle: "Beenden").hasDestructiveAction = true
        alert.addButton(withTitle: "Abbrechen")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        for controller in controllers {
            controller.disconnect(nil)
            controller.cancelTransfer(nil)   // entfernt eine angefangene Teildatei sofort
        }
        removeQuickSessions()   // plink hat die Sitzungen beim Start gelesen
    }

    // MARK: - Links aus anderen Apps (M7, S6)

    /// `ssh://` und `telnet://` (Info.plist `CFBundleURLTypes`). Mehrere Links auf einmal kann nur eine Webseite oder
    /// ein Skript auslösen: nur der erste zählt, auch vor dem Ende des Starts.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        if urls.count > 1 { AppLog.app.info("Link: \(urls.count - 1, privacy: .public) weitere verworfen") }
        if library == nil {
            if pendingLink == nil { pendingLink = first.absoluteString }   // vor applicationDidFinishLaunching
        } else {
            openLink(first.absoluteString)
        }
    }

    /// Rückfrage im vordersten Fenster (ein freier Tab verbindet selbst, sonst ein neuer daneben); ohne Fenster (die App
    /// läuft nach dem letzten weiter) oder mit offenem Sheet in einem neuen Fenster.
    private func openLink(_ text: String) {
        if let open = linkPromptWindow, open.attachedSheet != nil, controllers.contains(where: { $0.window === open }) {
            AppLog.app.info("Link verworfen: eine Rückfrage ist noch offen")
            return
        }
        let front: ConnectionWindowController? = keyController ?? controllers.last
        guard let target = front.flatMap({ $0.window?.attachedSheet == nil ? $0 : nil }) ?? frontController() else { return }
        target.showWindow(nil)
        linkPromptWindow = target.window
        target.openLink(text) { [weak self] in
            self?.linkPromptWindow = nil
        }
    }

    // MARK: - Fenster

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

    // MARK: - Hilfe (M7)

    /// Über-Fenster mit Lizenzen (App-Menü).
    @objc func showAbout(_ sender: Any?) {
        AboutPanel.show()
    }

    @objc func showQuickStart(_ sender: Any?) {
        if quickStartWindow == nil { quickStartWindow = QuickStartWindowController() }
        quickStartWindow?.showWindow(nil)
    }

    /// Liest die Menüleiste bei jedem Öffnen neu.
    @objc func showShortcuts(_ sender: Any?) {
        let entries: [ShortcutOverview.Entry] = ShortcutOverview.entries(from: NSApp.mainMenu) + ShortcutOverview.withoutMenu
        if let shortcutsWindow, let hosting = shortcutsWindow.contentViewController as? NSHostingController<ShortcutsView> {
            hosting.rootView = ShortcutsView(entries: entries)
        } else {
            shortcutsWindow = ToolWindowController(title: "Tastenkürzel", autosaveName: "Tastenkürzel",
                                                   rootView: ShortcutsView(entries: entries))
        }
        shortcutsWindow?.showWindow(nil)
    }

    /// Hilfe › PuTTY-Version (S7): eingebaute Version und wie Updates kommen.
    @objc func showPuTTYVersion(_ sender: Any?) {
        Task {
            let release: String? = await PuTTYInfo.release()
            let alert: NSAlert = NSAlert()
            alert.messageText = release.map { "Eingebaut: PuTTY \($0)" } ?? "Die PuTTY-Version ist nicht lesbar."
            alert.informativeText = PuTTYInfo.updateNote
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "PuTTY-Website öffnen")
            let handle: (NSApplication.ModalResponse) -> Void = { response in
                if response == .alertSecondButtonReturn { NSWorkspace.shared.open(PuTTYInfo.website) }
            }
            // Als Sheet am vordersten Fenster, sonst blockiert der Dialog die ganze App (Richtlinien 3.4 Regel 18)
            if let window = NSApp.keyWindow, window.attachedSheet == nil {
                alert.beginSheetModal(for: window, completionHandler: handle)
            } else {
                handle(alert.runModal())
            }
        }
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
        // Läuft die App ein zweites Mal (z. B. aus dem DMG oder als Test-Host), gehören vorhandene Schnellsitzungen der
        // anderen Instanz: nicht löschen, sonst scheitert dort eine laufende Dateiübertragung (Härtung, Code-Review R-2)
        guard NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").count <= 1
        else { return }
        do {
            try AppIdentity.puttyDirectory().removeSessions(withPrefix: AppIdentity.quickSessionPrefix)
        } catch {
            AppLog.app.error("PuTTY-Ordner nicht erreichbar: \(error.localizedDescription, privacy: .private(mask: .hash))")
        }
    }
}
