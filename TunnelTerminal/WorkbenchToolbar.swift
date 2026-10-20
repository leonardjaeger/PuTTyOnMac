import AppKit

/// Symbolleiste des Hauptfensters (Plan 3.1): Seitenleiste, Hochladen (M6), Tunnel (M5), Trennen, Inspektor. Die Knöpfe
/// schicken ihre Befehle über die Responder-Kette an den Fenster-Controller; dort werden sie auch geprüft
/// (`validateToolbarItem`). Jeder Befehl steht auch im Menü „Verbindung“ (RL 3.4 Regel 5).
final class WorkbenchToolbar: NSObject, NSToolbarDelegate {
    static let disconnect: NSToolbarItem.Identifier = NSToolbarItem.Identifier("trennen")
    static let tunnel: NSToolbarItem.Identifier = NSToolbarItem.Identifier("tunnel")
    static let upload: NSToolbarItem.Identifier = NSToolbarItem.Identifier("hochladen")

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace, Self.upload, Self.tunnel, Self.disconnect,
         .inspectorTrackingSeparator, .flexibleSpace, .toggleInspector]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item: NSToolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        switch itemIdentifier {
        case Self.disconnect:
            item.label = "Trennen"
            item.toolTip = "Verbindung trennen (⌘.)"
            item.image = NSImage(systemSymbolName: "bolt.horizontal.circle", accessibilityDescription: "Trennen")
            item.action = #selector(ConnectionWindowController.disconnect(_:))
        case Self.tunnel:
            item.label = "Tunnel"
            item.toolTip = "Port-Weiterleitungen dieser Sitzung bearbeiten"
            item.image = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted", accessibilityDescription: "Tunnel")
            item.action = #selector(ConnectionWindowController.editTunnels(_:))
        case Self.upload:
            item.label = "Hochladen"
            item.toolTip = "Dateien auf den Server hochladen (auch: Dateien aufs Terminal ziehen)"
            item.image = NSImage(systemSymbolName: "arrow.up.doc", accessibilityDescription: "Hochladen")   // nicht das Teilen-Symbol
            item.action = #selector(ConnectionWindowController.uploadFiles(_:))
        default:
            return nil
        }
        return item
    }
}
