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
        file.addItem(item("Neue Sitzung", #selector(AppDelegate.newSession(_:)), "n", [.command, .shift]))
        let importing: NSMenuItem = item("Importieren", nil)
        importing.submenu = NSMenu(title: "Importieren")
        importing.submenu?.addItem(item("Registrierungsdatei (.reg) …", #selector(ConnectionWindowController.importRegistry(_:))))
        importing.submenu?.addItem(item("PuTTY-Ordner …", #selector(ConnectionWindowController.importFolder(_:))))
        file.addItem(importing)
        let export: NSMenuItem = item("Exportieren", nil)
        export.submenu = NSMenu(title: "Exportieren")
        export.submenu?.addItem(item("Als Registrierungsdatei (.reg) …", #selector(ConnectionWindowController.exportRegistry(_:))))
        export.submenu?.addItem(item("Als PuTTY-Ordner …", #selector(ConnectionWindowController.exportFolder(_:))))
        file.addItem(export)
        file.addItem(.separator())
        file.addItem(item("Schließen", #selector(NSWindow.performClose(_:)), "w"))

        let edit: NSMenu = submenu("Bearbeiten", in: main)
        edit.addItem(item("Widerrufen", Selector(("undo:")), "z"))
        edit.addItem(item("Wiederholen", Selector(("redo:")), "z", [.command, .shift]))
        edit.addItem(.separator())
        edit.addItem(item("Ausschneiden", #selector(NSText.cut(_:)), "x"))
        edit.addItem(item("Kopieren", #selector(NSText.copy(_:)), "c"))
        edit.addItem(item("Einsetzen", #selector(NSText.paste(_:)), "v"))
        edit.addItem(item("Alles auswählen", #selector(NSText.selectAll(_:)), "a"))
        edit.addItem(.separator())
        // Duplizieren ohne Kürzel: ⌘D ist für M4 vorgesehen
        edit.addItem(item("Duplizieren", #selector(ConnectionWindowController.duplicateSessions(_:))))
        edit.addItem(item("Löschen", #selector(ConnectionWindowController.deleteSessions(_:)), "\u{8}"))

        // Ein-/Ausblenden über NSSplitViewController (Gerüst B, Plan 3.1); ⌥⌘I für den Inspektor wie in Pages (RL 3.5)
        let view: NSMenu = submenu("Darstellung", in: main)
        view.addItem(item("Seitenleiste ein-/ausblenden", #selector(NSSplitViewController.toggleSidebar(_:)), "s", [.command, .control]))
        view.addItem(item("Inspektor ein-/ausblenden", #selector(NSSplitViewController.toggleInspector(_:)), "i", [.command, .option]))
        view.addItem(.separator())
        view.addItem(item("Vollbild", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]))

        // Eigenes Menü hinter „Darstellung“, vor „Fenster“ (RL 2.2 / 3.4 Regel 5)
        let connection: NSMenu = submenu("Verbindung", in: main)
        // ⇧⌘K wie „Neue entfernte Verbindung“ in Terminal.app; ⌘K bleibt für M4 (Bildschirm leeren)
        connection.addItem(item("Schnellverbindung", #selector(ConnectionWindowController.focusQuickConnect(_:)), "k", [.command, .shift]))
        connection.addItem(.separator())
        connection.addItem(item("Verbinden", #selector(ConnectionWindowController.connectSessions(_:))))
        connection.addItem(item("Sitzung bearbeiten …", #selector(ConnectionWindowController.editSession(_:))))
        connection.addItem(.separator())
        connection.addItem(item("Erneut verbinden", #selector(ConnectionWindowController.reconnect(_:)), "r"))
        connection.addItem(item("Trennen", #selector(ConnectionWindowController.disconnect(_:)), "."))

        let window: NSMenu = submenu("Fenster", in: main)
        window.addItem(item("Im Dock ablegen", #selector(NSWindow.performMiniaturize(_:)), "m"))
        window.addItem(item("Zoomen", #selector(NSWindow.performZoom(_:))))
        window.addItem(.separator())
        window.addItem(item("Schlüssel", #selector(AppDelegate.showKeys(_:))))
        window.addItem(item("Bekannte Hostschlüssel", #selector(AppDelegate.showKnownHosts(_:))))
        window.addItem(.separator())
        window.addItem(item("Alle nach vorne bringen", #selector(NSApplication.arrangeInFront(_:))))
        NSApp.windowsMenu = window

        // Hinweis zur Anmeldung mit Schlüssel und macOS-Agent (Plan M3) steht im Fenster „Schlüssel“
        let help: NSMenu = submenu("Hilfe", in: main)
        help.addItem(item("Anmeldung mit Schlüssel und Agent", #selector(AppDelegate.showKeys(_:))))
        NSApp.helpMenu = help
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
