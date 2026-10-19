import AppKit
import XCTest
@testable import TunnelTerminal

@MainActor
final class MainMenuTests: XCTestCase {
    /// Kein Tastenkürzel doppelt belegt (wie bei MintMarkPDF).
    func testShortcutsAreUnique() {
        var seen: [String: String] = [:]
        var duplicates: [String] = []
        func walk(_ menu: NSMenu) {
            for item in menu.items {
                if let submenu = item.submenu { walk(submenu) }
                guard !item.keyEquivalent.isEmpty else { continue }
                let key: String = "\(item.keyEquivalentModifierMask.rawValue)-\(item.keyEquivalent)"
                if let other = seen[key] { duplicates.append("\(other) / \(item.title)") }
                seen[key] = item.title
            }
        }
        walk(MainMenu.build())
        XCTAssertTrue(duplicates.isEmpty, "\(duplicates)")
        XCTAssertGreaterThan(seen.count, 8)
    }

    /// Standardreihenfolge der Menüs, eigene Menüs zwischen „Darstellung“ und „Fenster“ (RL 2.2, 3.4 Regel 5).
    func testMenuOrder() {
        XCTAssertEqual(MainMenu.build().items.map(\.title),
                       [AppIdentity.name, "Ablage", "Bearbeiten", "Darstellung", "Verbindung", "Fenster", "Hilfe"])
    }

    /// Gerüst B: Seitenleiste ⌃⌘S, Inspektor ⌥⌘I, Schnellverbindung ⇧⌘K; ⌘K bleibt für M4 frei, „Sitzungen“-Fenster gibt es nicht mehr.
    func testWorkbenchCommands() throws {
        let menu: NSMenu = MainMenu.build()
        var all: [NSMenuItem] = []
        func walk(_ menu: NSMenu) {
            for item in menu.items {
                all.append(item)
                if let submenu = item.submenu { walk(submenu) }
            }
        }
        walk(menu)
        func item(_ action: Selector) throws -> NSMenuItem { try XCTUnwrap(all.first { $0.action == action }) }
        let sidebar: NSMenuItem = try item(#selector(NSSplitViewController.toggleSidebar(_:)))
        XCTAssertEqual(sidebar.keyEquivalent, "s")
        XCTAssertEqual(sidebar.keyEquivalentModifierMask, [.command, .control])
        let inspector: NSMenuItem = try item(#selector(NSSplitViewController.toggleInspector(_:)))
        XCTAssertEqual(inspector.keyEquivalent, "i")
        XCTAssertEqual(inspector.keyEquivalentModifierMask, [.command, .option])
        let quick: NSMenuItem = try item(#selector(ConnectionWindowController.focusQuickConnect(_:)))
        XCTAssertEqual(quick.keyEquivalent, "k")
        XCTAssertEqual(quick.keyEquivalentModifierMask, [.command, .shift])
        XCTAssertFalse(all.contains { $0.keyEquivalent == "k" && $0.keyEquivalentModifierMask == .command })
        XCTAssertFalse(all.contains { $0.title == "Sitzungen" })
    }

    /// ⌘Z/⇧⌘Z für Sitzungen (Plan M2), ⌘⌫ löscht Sitzungen; Duplizieren ohne Kürzel (⌘D bleibt für M4 frei).
    func testEditMenuHasUndoAndSessionCommands() throws {
        let edit: NSMenu = try XCTUnwrap(MainMenu.build().items.first { $0.title == "Bearbeiten" }?.submenu)
        let byTitle: [String: NSMenuItem] = Dictionary(uniqueKeysWithValues: edit.items.filter { !$0.isSeparatorItem }
            .map { ($0.title, $0) })
        XCTAssertEqual(byTitle["Widerrufen"]?.action, Selector(("undo:")))
        XCTAssertEqual(byTitle["Widerrufen"]?.keyEquivalent, "z")
        XCTAssertEqual(byTitle["Wiederholen"]?.keyEquivalentModifierMask, [.command, .shift])
        XCTAssertEqual(byTitle["Löschen"]?.keyEquivalent, "\u{8}")
        XCTAssertEqual(byTitle["Duplizieren"]?.keyEquivalent, "")
    }

    /// Schlüssel und bekannte Hostschlüssel im Fenster-Menü, der Agent-Hinweis in der Hilfe (M3).
    func testKeyWindowsInMenus() throws {
        let menu: NSMenu = MainMenu.build()
        let window: NSMenu = try XCTUnwrap(menu.items.first { $0.title == "Fenster" }?.submenu)
        XCTAssertTrue(window.items.contains { $0.action == #selector(AppDelegate.showKeys(_:)) })
        XCTAssertTrue(window.items.contains { $0.action == #selector(AppDelegate.showKnownHosts(_:)) })
        let help: NSMenu = try XCTUnwrap(menu.items.first { $0.title == "Hilfe" }?.submenu)
        XCTAssertEqual(help.items.first?.action, #selector(AppDelegate.showKeys(_:)))
    }
}
