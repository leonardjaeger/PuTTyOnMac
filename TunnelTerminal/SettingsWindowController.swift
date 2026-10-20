import AppKit
import SwiftUI

/// Einstellungen (⌘,) in Reitern im Stil der Symbolleiste (Richtlinien 3.4 Regel 16). M4: Allgemein und Profile;
/// Sicherheit und Erweitert folgen in M7.
final class SettingsWindowController: NSWindowController {
    init(profiles: ProfileStore) {
        let tabs: NSTabViewController = NSTabViewController()
        tabs.tabStyle = .toolbar
        func add<Content: View>(_ title: String, symbol: String, _ root: Content) {
            let hosting: NSHostingController<Content> = NSHostingController(rootView: root)
            hosting.sizingOptions = [.preferredContentSize]   // Fenster folgt der Größe des Reiters
            let item: NSTabViewItem = NSTabViewItem(viewController: hosting)
            item.label = title
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            tabs.addTabViewItem(item)
        }
        add("Allgemein", symbol: "gearshape", GeneralSettingsView())
        add("Profile", symbol: "paintpalette", ProfilesSettingsView(store: profiles))
        let window: NSWindow = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isRestorable = false
        super.init(window: window)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht benutzt") }
}
