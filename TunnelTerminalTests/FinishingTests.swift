import AppKit
import SwiftTerm
import TunnelTerminalCore
import XCTest
@testable import TunnelTerminal

/// M7 Feinschliff & Weitergabe: Links aus anderen Apps (S6), Einstellungen › Sicherheit, Menü- und Symbolleisten-Regeln,
/// Kürzel-Übersicht, Über-Fenster, Kurzanleitung. Eigener PuTTY-Ordner und eigene Einstellungen je Test (RL 3.9), nur
/// Platzhalter (S14).
@MainActor
final class FinishingTests: XCTestCase {
    private var library: SessionLibrary!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        library = SessionLibrary(directory: try PuTTYDirectory(url: folder))
        let suite: String = "TunnelTerminalTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
    }

    private func makeWindow() -> ConnectionWindowController {
        let controller: ConnectionWindowController = ConnectionWindowController(library: library, connected: ConnectedSessions())
        addTeardownBlock { @MainActor in controller.window?.close() }
        controller.showWindow(nil)
        return controller
    }

    // MARK: Links aus anderen Apps (S6)

    /// Prüfpunkt M7: `ssh://-oProxyCommand=x@…` wird abgelehnt, ohne zu verbinden.
    func testLinkWithOptionIsRefused() throws {
        let controller: ConnectionWindowController = makeWindow()
        let window: NSWindow = try XCTUnwrap(controller.window)
        var closed: Bool = false
        controller.openLink("ssh://-oProxyCommand=x@server.example") { closed = true }
        let sheet: NSWindow = try XCTUnwrap(window.attachedSheet)
        let texts: [String] = Self.texts(in: sheet.contentView)
        XCTAssertTrue(texts.contains("Dieser Link wird nicht geöffnet."))
        XCTAssertTrue(texts.contains { $0.contains("Benutzername darf nicht mit „-“ beginnen.") })
        XCTAssertFalse(texts.contains("Verbinden"))
        window.endSheet(sheet)
        XCTAssertTrue(closed)
        XCTAssertNil(controller.terminal)
    }

    /// Bestätigung mit vollständiger Adresse; „Abbrechen“ verbindet nicht.
    func testLinkNeedsConfirmation() throws {
        let controller: ConnectionWindowController = makeWindow()
        let window: NSWindow = try XCTUnwrap(controller.window)
        controller.openLink("ssh://test@server.example:2222")
        let sheet: NSWindow = try XCTUnwrap(window.attachedSheet)
        let texts: [String] = Self.texts(in: sheet.contentView)
        XCTAssertTrue(texts.contains("Verbindung aus einem Link öffnen?"))
        // Server zuerst, die vollständige Adresse dahinter (Prüfer M7, Befund 2)
        XCTAssertTrue(texts.contains { $0.hasPrefix("Server: server.example\nPort: 2222\nBenutzer: test")
            && $0.contains("Link: ssh://test@server.example:2222") })
        XCTAssertTrue(texts.contains("Abbrechen"))
        window.endSheet(sheet, returnCode: .alertFirstButtonReturn)   // „Abbrechen“
        XCTAssertNil(controller.terminal)
        XCTAssertEqual(window.title, "Neue Verbindung")
    }

    /// „Verbinden“ öffnet die Verbindung im freien Tab (hier Telnet zu einem lauschenden Test-Socket).
    func testConfirmedLinkConnects() throws {
        let server: (descriptor: Int32, port: Int) = try localSocket(listening: true)
        addTeardownBlock { close(server.descriptor) }
        let controller: ConnectionWindowController = makeWindow()
        let window: NSWindow = try XCTUnwrap(controller.window)
        controller.openLink("telnet://127.0.0.1:\(server.port)/")
        window.endSheet(try XCTUnwrap(window.attachedSheet), returnCode: .alertSecondButtonReturn)   // „Verbinden“
        let client: Int32 = try accept(on: server.descriptor)
        addTeardownBlock { close(client) }
        XCTAssertTrue(controller.isConnected)
        XCTAssertEqual(window.title, "127.0.0.1:\(server.port)")
        controller.disconnect(nil)
    }

    /// Ein abgelehnter Link mit Passwort zeigt das Passwort nicht (RFC 3986 3.2.1), auch nicht kodiert.
    func testRefusedLinkHidesPassword() throws {
        let controller: ConnectionWindowController = makeWindow()
        let window: NSWindow = try XCTUnwrap(controller.window)
        for link in ["ssh://test:geheim@server.example", "ssh://test%3Ageheim@server.example"] {
            controller.openLink(link)
            let sheet: NSWindow = try XCTUnwrap(window.attachedSheet)
            let texts: [String] = Self.texts(in: sheet.contentView)
            XCTAssertTrue(texts.contains { $0.contains("Passwörter übernimmt die App nie aus Links") }, link)
            XCTAssertFalse(texts.contains { $0.contains("geheim") }, link)
            window.endSheet(sheet)
        }
    }

    /// Telnet-Links nennen den Klartext, SSH-Links den Agenten.
    func testLinkDetailsWarn() throws {
        let telnet: String = AppLinkPrompt.details(of: try ConnectionLink(parsing: "telnet://192.0.2.10"))
        XCTAssertTrue(telnet.contains("Port: 23 (Standard)"))
        XCTAssertTrue(telnet.contains("unverschlüsselt"))
        XCTAssertTrue(AppLinkPrompt.details(of: try ConnectionLink(parsing: "ssh://server.example")).contains("Agenten"))
        XCTAssertFalse(AppLinkPrompt.containsPassword("ssh://test@server.example:22"))
        XCTAssertTrue(AppLinkPrompt.containsPassword("SSH://a:b@server.example/"))
    }

    /// Einstellungen › Sicherheit „Nie öffnen“: auch gültige Links werden nur gemeldet.
    func testBlockedLinksAreOnlyReported() throws {
        let controller: ConnectionWindowController = makeWindow()
        let window: NSWindow = try XCTUnwrap(controller.window)
        defaults.set(true, forKey: AppSettings.blockAppLinks)
        controller.openLink("ssh://test@server.example", defaults: defaults)
        let sheet: NSWindow = try XCTUnwrap(window.attachedSheet)
        XCTAssertTrue(Self.texts(in: sheet.contentView).contains { $0.contains("unter Einstellungen › Sicherheit abgeschaltet") })
        XCTAssertFalse(Self.texts(in: sheet.contentView).contains("Verbinden"))
        window.endSheet(sheet)
    }

    // MARK: Einstellungen › Sicherheit (S11)

    func testBlockedServerRequests() throws {
        let window: NSWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled],
                                        backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false   // sonst gibt close() das Fenster unter ARC ein zweites Mal frei
        addTeardownBlock { @MainActor in window.close() }
        window.makeKeyAndOrderFront(nil)
        let prompts: ServerRequestPrompts = ServerRequestPrompts(defaults: defaults)
        defaults.set(true, forKey: AppSettings.blockServerClipboard)
        prompts.clipboardCopy(Data("rm -rf ~".utf8), in: window)
        XCTAssertNil(window.attachedSheet, "abgeschaltet: nicht einmal fragen")
        defaults.set(true, forKey: AppSettings.blockTerminalLinks)
        prompts.openLink("https://server.example/x", in: window)
        let sheet: NSWindow = try XCTUnwrap(window.attachedSheet)
        XCTAssertTrue(Self.texts(in: sheet.contentView).contains { $0.contains("Links aus dem Terminal sind unter Einstellungen") })
        XCTAssertFalse(Self.texts(in: sheet.contentView).contains("Öffnen"))
        window.endSheet(sheet)
    }

    // MARK: Menü und Symbolleiste

    /// Bei offenem Sheet bleibt nur Trennen; „Erneut verbinden“ erst, wenn plink beendet ist.
    func testCommandRules() {
        var state: TabCommandState = TabCommandState(hasSheet: true, isConnected: true, hasConnection: true, hasTerminal: true,
                                                     canEditTunnels: true)
        XCTAssertTrue(state.allows(#selector(ConnectionWindowController.disconnect(_:))))
        XCTAssertFalse(state.allows(#selector(ConnectionWindowController.clearScreenAndHistory(_:))))
        XCTAssertFalse(state.allows(#selector(ConnectionWindowController.editTunnels(_:))), "Symbolleiste „Tunnel“ bei Sheet")
        state.hasSheet = false
        XCTAssertTrue(state.allows(#selector(ConnectionWindowController.editTunnels(_:))))
        XCTAssertFalse(state.allows(#selector(ConnectionWindowController.reconnect(_:))))
        state.isConnected = false
        XCTAssertTrue(state.allows(#selector(ConnectionWindowController.reconnect(_:))))
        XCTAssertFalse(state.allows(#selector(ConnectionWindowController.disconnect(_:))))
        state.savedSelection = [SessionName.defaultSettings]
        XCTAssertFalse(state.allows(#selector(ConnectionWindowController.duplicateSessions(_:))))
    }

    /// Symbolleisten-Knöpfe haben die Aktionen der Menübefehle (dieselben Regeln, jeder Befehl auch im Menü, RL 3.4 Regel 5).
    func testToolbarButtonsUseMenuActions() throws {
        let toolbar: WorkbenchToolbar = WorkbenchToolbar()
        let bar: NSToolbar = NSToolbar(identifier: "Test")
        var actions: [Selector] = []
        for identifier in [WorkbenchToolbar.disconnect, WorkbenchToolbar.tunnel, WorkbenchToolbar.upload] {
            let item: NSToolbarItem = try XCTUnwrap(toolbar.toolbar(bar, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: true))
            actions.append(try XCTUnwrap(item.action))
        }
        var menuActions: Set<Selector> = []
        func walk(_ menu: NSMenu) {
            for item in menu.items {
                if let action = item.action { menuActions.insert(action) }
                if let submenu = item.submenu { walk(submenu) }
            }
        }
        walk(MainMenu.build())
        XCTAssertTrue(actions.allSatisfy(menuActions.contains))
        XCTAssertEqual(AdvancedSettingsModel.schemes, ["ssh", "telnet"], "Info.plist CFBundleURLTypes")
    }

    /// Kürzel-Übersicht: liest die Menüleiste, Zusatztasten in der Reihenfolge ⌃ ⌥ ⇧ ⌘ (RL 3.5 Regel 4).
    func testShortcutOverview() {
        XCTAssertEqual(ShortcutOverview.label(key: "k", modifiers: [.command, .shift]), "⇧⌘K")
        XCTAssertEqual(ShortcutOverview.label(key: "s", modifiers: [.command, .control]), "⌃⌘S")
        XCTAssertEqual(ShortcutOverview.label(key: "\u{8}", modifiers: .command), "⌘⌫")
        // Einträge, die macOS selbst einsetzt (Prüfer M7, Befund 4)
        XCTAssertEqual(ShortcutOverview.label(key: "\t", modifiers: .control), "⌃⇥")
        XCTAssertEqual(ShortcutOverview.label(key: "\u{F702}", modifiers: [.function, .control]), "fn⌃←")
        XCTAssertEqual(ShortcutOverview.label(key: "f", modifiers: [.function, .control]), "fn⌃F")
        XCTAssertEqual(ShortcutOverview.label(key: "\u{F705}", modifiers: []), "F2")
        XCTAssertEqual(ShortcutOverview.label(key: "T", modifiers: .command), "⇧⌘T")
        let system: NSMenu = NSMenu()
        let window: NSMenuItem = system.addItem(withTitle: "Fenster", action: nil, keyEquivalent: "")
        window.submenu = NSMenu(title: "Fenster")
        window.submenu?.addItem(withTitle: "Nächsten Tab zeigen", action: nil, keyEquivalent: "\t").keyEquivalentModifierMask = .control
        // NSMenuItem behält .function nicht (Setter filtert); die Pfeiltaste muss trotzdem lesbar sein
        window.submenu?.addItem(withTitle: "Links", action: nil, keyEquivalent: "\u{F702}").keyEquivalentModifierMask = .control
        XCTAssertEqual(ShortcutOverview.entries(from: system).map(\.keys), ["⌃⇥", "⌃←"])
        let entries: [ShortcutOverview.Entry] = ShortcutOverview.entries(from: MainMenu.build())
        XCTAssertTrue(entries.contains(ShortcutOverview.Entry(group: "Verbindung", title: "Trennen", keys: "⌘.")))
        XCTAssertTrue(entries.contains(ShortcutOverview.Entry(group: "Bearbeiten", title: "Suchen › Weitersuchen", keys: "⌘G")))
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
    }

    // MARK: Über-Fenster und Kurzanleitung

    /// Lizenzen aus dem App-Paket (MIT verlangt den Text in jeder Kopie); einzige persönliche Angabe ist der Autor (S14).
    func testAboutPanelShowsLicenses() {
        let credits: String = AboutPanel.credits().string
        XCTAssertTrue(credits.contains("MIT License"))
        XCTAssertTrue(credits.contains("Copyright (c) 2026 Leonard Jäger"))
        XCTAssertTrue(credits.contains("PuTTY is copyright 1997-2026 Simon Tatham."))
        XCTAssertTrue(credits.contains("Miguel de Icaza"))
        XCTAssertFalse(credits.contains("```"))
    }

    func testQuickStartGuideIsBundled() {
        let start: Date = .now
        let guide: String = QuickStartWindowController.guide().string
        let milliseconds: Int = Int(Date.now.timeIntervalSince(start) * 1000)
        print("Kurzanleitung geladen in \(milliseconds) ms")
        XCTAssertLessThan(milliseconds, 100, "Hauptthread (Richtlinien 3.7)")
        XCTAssertTrue(guide.contains("TunnelTerminal – Kurzanleitung"))
        XCTAssertTrue(guide.contains("PuTTY-Updates"))
        XCTAssertFalse(guide.contains("fehlt im App-Paket"))
    }

    /// Texte und Knopftitel in einem Sheet (NSAlert legt beides als Unteransichten an).
    private static func texts(in root: NSView?) -> [String] {
        guard let root else { return [] }
        var result: [String] = []
        if let field = root as? NSTextField { result.append(field.stringValue) }
        if let button = root as? NSButton { result.append(button.title) }
        for child in root.subviews { result += texts(in: child) }
        return result
    }
}
