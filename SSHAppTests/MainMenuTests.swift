import AppKit
import XCTest
@testable import SSHApp

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
}
