import AppKit
import SSHAppCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controllers: [ConnectionWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build()
        removeQuickSessions()   // Reste nach einem Absturz
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
        makeController().showWindow(nil)
    }

    /// ⌘T und „+“ in der Tab-Leiste: neuer Tab mit der Schnellverbindung, vorbelegt mit der Adresse des aktiven Tabs.
    @objc func newWindowForTab(_ sender: Any?) {
        let current: ConnectionWindowController? = controllers.first { $0.window === NSApp.keyWindow }
        let controller: ConnectionWindowController = makeController(address: current?.address)
        guard let tabWindow = controller.window else { return }
        current?.window?.addTabbedWindow(tabWindow, ordered: .above)
        tabWindow.makeKeyAndOrderFront(nil)
    }

    private func makeController(address: (text: String, connectionProtocol: ConnectionProtocol)? = nil)
        -> ConnectionWindowController {
        let controller: ConnectionWindowController = ConnectionWindowController(
            address: address?.text ?? "", connectionProtocol: address?.connectionProtocol ?? .ssh)
        controller.onClose = { [weak self] closed in self?.controllers.removeAll { $0 === closed } }
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
