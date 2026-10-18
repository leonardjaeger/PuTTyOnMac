import AppKit

/// Menüleiste in der Standardreihenfolge (Richtlinien 3.4 Regel 5). Befehle ohne Ziel laufen über die
/// Responder-Kette: Fenster-Controller (Verbindung) bzw. App-Delegate (Fenster und Tabs).
enum MainMenu {
    static func build() -> NSMenu {
        let name: String = AppIdentity.name
        let main: NSMenu = NSMenu()

        let app: NSMenu = submenu(name, in: main)
        app.addItem(item("Über \(name)", #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
        app.addItem(.separator())
        let services: NSMenuItem = item("Dienste", nil)
        services.submenu = NSMenu(title: "Dienste")
        NSApp.servicesMenu = services.submenu
        app.addItem(services)
        app.addItem(.separator())
        app.addItem(item("\(name) ausblenden", #selector(NSApplication.hide(_:)), "h"))
        app.addItem(item("Andere ausblenden", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        app.addItem(item("Alle einblenden", #selector(NSApplication.unhideAllApplications(_:))))
        app.addItem(.separator())
        app.addItem(item("\(name) beenden", #selector(NSApplication.terminate(_:)), "q"))

        let file: NSMenu = submenu("Ablage", in: main)
        file.addItem(item("Neues Fenster", #selector(AppDelegate.newWindow(_:)), "n"))
        file.addItem(item("Neuer Tab", #selector(NSResponder.newWindowForTab(_:)), "t"))
        file.addItem(.separator())
        file.addItem(item("Schließen", #selector(NSWindow.performClose(_:)), "w"))

        let edit: NSMenu = submenu("Bearbeiten", in: main)
        edit.addItem(item("Kopieren", #selector(NSText.copy(_:)), "c"))
        edit.addItem(item("Einsetzen", #selector(NSText.paste(_:)), "v"))
        edit.addItem(item("Alles auswählen", #selector(NSText.selectAll(_:)), "a"))

        let view: NSMenu = submenu("Darstellung", in: main)
        view.addItem(item("Vollbild", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]))

        // Eigenes Menü hinter „Darstellung“, vor „Fenster“ (RL 2.2 / 3.4 Regel 5)
        let connection: NSMenu = submenu("Verbindung", in: main)
        connection.addItem(item("Erneut verbinden", #selector(ConnectionWindowController.reconnect(_:)), "r"))
        connection.addItem(item("Trennen", #selector(ConnectionWindowController.disconnect(_:)), "."))

        let window: NSMenu = submenu("Fenster", in: main)
        window.addItem(item("Im Dock ablegen", #selector(NSWindow.performMiniaturize(_:)), "m"))
        window.addItem(item("Zoomen", #selector(NSWindow.performZoom(_:))))
        window.addItem(.separator())
        window.addItem(item("Alle nach vorne bringen", #selector(NSApplication.arrangeInFront(_:))))
        NSApp.windowsMenu = window

        NSApp.helpMenu = submenu("Hilfe", in: main)
        return main
    }

    private static func submenu(_ title: String, in main: NSMenu) -> NSMenu {
        let menu: NSMenu = NSMenu(title: title)
        let holder: NSMenuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        holder.submenu = menu
        main.addItem(holder)
        return menu
    }

    private static func item(_ title: String, _ action: Selector?, _ key: String = "",
                             _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let menuItem: NSMenuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.keyEquivalentModifierMask = modifiers
        return menuItem
    }
}
