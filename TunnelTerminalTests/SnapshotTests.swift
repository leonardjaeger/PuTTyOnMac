import AppKit
import SwiftUI
import XCTest
@testable import TunnelTerminal

/// Bilder der Fenster, die nur über das Menü erreichbar sind (Einstellungen, Tastenkürzel, Kurzanleitung), in Hell und
/// Dunkel – für die eigene Oberflächenprüfung (M7: Claude darf in der App keine Menüs bedienen). Läuft nur mit
/// `TUNNELTERMINAL_SNAPSHOTS=<Ordner>` (über `build/m7/ui.sh snap`), sonst übersprungen.
@MainActor
final class SnapshotTests: XCTestCase {
    func testRenderMenuOnlyWindows() throws {
        guard let folder = ProcessInfo.processInfo.environment["TUNNELTERMINAL_SNAPSHOTS"] else {
            throw XCTSkip("nur mit TUNNELTERMINAL_SNAPSHOTS")
        }
        let output: URL = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let entries: [ShortcutOverview.Entry] = ShortcutOverview.entries(from: MainMenu.build()) + ShortcutOverview.withoutMenu
        for (suffix, appearance) in [("hell", NSAppearance.Name.aqua), ("dunkel", .darkAqua)] {
            try render(SecuritySettingsView(), size: NSSize(width: 520, height: 520), appearance: appearance,
                       to: output.appending(path: "sicherheit-\(suffix).png"))
            try render(AdvancedSettingsView(), size: NSSize(width: 520, height: 560), appearance: appearance,
                       to: output.appending(path: "erweitert-\(suffix).png"))
            try render(GeneralSettingsView(), size: NSSize(width: 520, height: 300), appearance: appearance,
                       to: output.appending(path: "allgemein-\(suffix).png"))
            try render(ShortcutsView(entries: entries), size: NSSize(width: 560, height: 900), appearance: appearance,
                       to: output.appending(path: "kuerzel-\(suffix).png"))
            try render(PasteBanner(lines: 3) { _ in }, size: NSSize(width: 700, height: 40), appearance: appearance,
                       to: output.appending(path: "einfuegen-\(suffix).png"))
            let guide: NSWindowController = QuickStartWindowController()
            guide.window?.appearance = NSAppearance(named: appearance)
            try snapshot(try XCTUnwrap(guide.window?.contentView), to: output.appending(path: "kurzanleitung-\(suffix).png"))
            guide.close()
        }
    }

    private func render<Content: View>(_ view: Content, size: NSSize, appearance: NSAppearance.Name, to url: URL) throws {
        let hosting: NSHostingView<Content> = NSHostingView(rootView: view)
        hosting.sizingOptions = []   // Größe vom Fenster, nicht vom Inhalt (Richtlinien 3.4 Regel 19)
        let window: NSWindow = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled],
                                        backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance)
        window.contentView = hosting
        window.orderFront(nil)
        RunLoop.main.run(until: Date.now.addingTimeInterval(1.5))   // .task (PuTTY-Version) und Layout abwarten
        try snapshot(hosting, to: url)
        window.close()
    }

    private func snapshot(_ view: NSView, to url: URL) throws {
        view.layoutSubtreeIfNeeded()
        let bitmap: NSBitmapImageRep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
    }
}
