import AppKit
import TunnelTerminalCore
import XCTest
@testable import TunnelTerminal

/// Gerüst B „Werkbank“ (Plan 3.1): Hauptfenster mit Seitenleiste, Inhalt und Inspektor; Schnellverbindung in der
/// Seitenleiste; Editor als Sheet; Status verbunden/getrennt. Eigener PuTTY-Ordner je Test (RL 3.9), nur Platzhalter (S14).
@MainActor
final class WorkbenchTests: XCTestCase {
    private var library: SessionLibrary!

    override func setUp() async throws {
        let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        library = SessionLibrary(directory: try PuTTYDirectory(url: folder))
    }

    private func makeWindow(showsInspector: Bool = true) -> ConnectionWindowController {
        let controller: ConnectionWindowController = ConnectionWindowController(
            library: library, connected: ConnectedSessions(), showsInspector: showsInspector)
        addTeardownBlock { @MainActor in controller.window?.close() }
        return controller
    }

    func testWindowHasSidebarContentAndInspector() throws {
        let controller: ConnectionWindowController = makeWindow(showsInspector: false)
        let split: NSSplitViewController = try XCTUnwrap(controller.window?.contentViewController as? NSSplitViewController)
        XCTAssertEqual(split.splitViewItems.map(\.behavior), [.sidebar, .default, .inspector])
        XCTAssertTrue(controller.showsSidebar)
        XCTAssertFalse(controller.showsInspector)
        let toolbar: [NSToolbarItem.Identifier] = try XCTUnwrap(controller.window?.toolbar?.items.map(\.itemIdentifier))
        XCTAssertTrue(toolbar.contains(.toggleSidebar) && toolbar.contains(.toggleInspector))
        XCTAssertEqual(controller.window?.title, "Neue Verbindung")
        XCTAssertEqual(controller.window?.tabbingIdentifier, ConnectionWindowController.tabbingIdentifier)
    }

    /// S3 auch über die Seitenleiste: Eine Option als Server wird abgelehnt, plink startet nicht.
    func testQuickConnectRejectsOptions() {
        let controller: ConnectionWindowController = makeWindow()
        controller.quick.address = "-proxycmd x"
        controller.quick.submit()
        XCTAssertNotNil(controller.quick.errorMessage)
        XCTAssertEqual(controller.quick.address, "-proxycmd x")
        XCTAssertFalse(controller.isConnected)
        XCTAssertEqual(controller.window?.title, "Neue Verbindung")
    }

    /// ⌘⌫ löscht keine Sitzung, solange die Sitzungsliste nicht den Fokus hat (z. B. im Terminal).
    func testDeleteNeedsFocusInSessionList() throws {
        try library.save(SessionFile(), as: "A")
        let controller: ConnectionWindowController = makeWindow()
        controller.sessions.selection = ["A"]
        let delete: NSMenuItem = NSMenuItem(title: "Löschen",
                                            action: #selector(ConnectionWindowController.deleteSessions(_:)), keyEquivalent: "")
        XCTAssertFalse(controller.validateMenuItem(delete))
        let duplicate: NSMenuItem = NSMenuItem(title: "Duplizieren",
                                               action: #selector(ConnectionWindowController.duplicateSessions(_:)), keyEquivalent: "")
        XCTAssertTrue(controller.validateMenuItem(duplicate))
    }

    /// Ja-Fall: Hat die Sitzungsliste selbst den Fokus, ist ⌘⌫ frei; bei offenem Sheet (Editor) nie (Prüfer-Befund 1).
    func testDeleteFollowsListFocusAndSheets() throws {
        try library.save(SessionFile(), as: "A")
        let controller: ConnectionWindowController = makeWindow()
        let window: NSWindow = try XCTUnwrap(controller.window)
        controller.sessions.selection = ["A"]
        window.layoutIfNeeded()
        window.displayIfNeeded()
        let list: NSTableView = try XCTUnwrap(Self.first(NSTableView.self, in: window.contentView), "Sitzungsliste nicht gefunden")
        XCTAssertTrue(window.makeFirstResponder(list))
        let delete: NSMenuItem = NSMenuItem(title: "Löschen",
                                            action: #selector(ConnectionWindowController.deleteSessions(_:)), keyEquivalent: "")
        XCTAssertTrue(controller.validateMenuItem(delete))

        let sheet: NSWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled],
                                       backing: .buffered, defer: false)
        window.beginSheet(sheet)
        defer { window.endSheet(sheet) }
        XCTAssertFalse(controller.validateMenuItem(delete))
        let connect: NSMenuItem = NSMenuItem(title: "Verbinden",
                                             action: #selector(ConnectionWindowController.connectSessions(_:)), keyEquivalent: "")
        XCTAssertFalse(controller.validateMenuItem(connect))
    }

    /// S4 auf Fensterebene: Eine Sitzung mit lokalem Proxy-Befehl startet über keinen Weg ohne Bestätigung.
    func testDangerousSessionNeedsConfirmationOnEveryPath() throws {
        var dangerous: SessionFile = SessionFile()
        try dangerous.setHostName("server.example")
        try dangerous.setValue("5", forKey: "ProxyMethod")
        try dangerous.setValue("nc %host %port", forKey: "ProxyTelnetCommand")
        try library.save(dangerous, as: "Gefahr")
        let controller: ConnectionWindowController = makeWindow()
        let window: NSWindow = try XCTUnwrap(controller.window)
        controller.showWindow(nil)                       // ein Sheet erscheint nur an einem sichtbaren Fenster
        controller.sessions.connect(["Gefahr"])          // Doppelklick, Kontext- und Menü „Verbinden“
        XCTAssertFalse(controller.isConnected)
        let deadline: Date = Date.now.addingTimeInterval(3)
        while window.attachedSheet == nil, Date.now < deadline { RunLoop.main.run(until: Date.now.addingTimeInterval(0.05)) }
        let sheet: NSWindow = try XCTUnwrap(window.attachedSheet, "Rückfrage fehlt")
        controller.reconnect(nil)                        // ⌘R während der Rückfrage stellt keine zweite
        XCTAssertFalse(controller.isConnected)
        XCTAssertTrue(window.attachedSheet === sheet)
        window.endSheet(sheet, returnCode: .alertFirstButtonReturn)   // „Abbrechen“
        XCTAssertFalse(controller.isConnected)
    }

    /// „Verbinden“ im Editor-Sheet folgt einem Umbenennen beim Schließen (Prüfer-Befund 6).
    func testPendingConnectionFollowsRename() throws {
        try library.save(SessionFile(), as: "Alt")
        let model: SessionsModel = SessionsModel(library: library)
        var connected: [String] = []
        model.onConnect = { connected.append($0) }
        model.edit("Alt")
        model.pendingConnection = "Alt"
        model.editing = nil
        try model.rename("Alt", to: "Neu")   // wie onDisappear des Editors
        model.connectAfterEditing()
        XCTAssertEqual(connected, ["Neu"])
        model.connectAfterEditing()
        XCTAssertEqual(connected, ["Neu"])   // nur einmal
    }

    /// Nachladen ohne Änderung und das erste Speichern der Standardeinstellungen bauen den Editor nicht neu auf
    /// (Prüfer-Befund 7); eigene Änderungen schon.
    func testRevisionChangesOnlyWithRealChanges() throws {
        let start: Int = library.revision
        library.reload()
        XCTAssertEqual(library.revision, start)
        try library.save(library.template(), as: SessionName.defaultSettings)
        XCTAssertEqual(library.revision, start)
        XCTAssertTrue(library.names.contains(SessionName.defaultSettings))
        try library.create(undoManager: nil)
        XCTAssertGreaterThan(library.revision, start)
    }

    /// Erste Ansicht dieses Typs im Baum (Tiefensuche).
    private static func first<View: NSView>(_ type: View.Type, in root: NSView?) -> View? {
        guard let root else { return nil }
        if let match = root as? View { return match }
        for child in root.subviews { if let match = first(type, in: child) { return match } }
        return nil
    }

    /// Neue Sitzung öffnet den Editor und blendet dafür die Seitenleiste ein (das Sheet hängt an ihr).
    func testNewSessionOpensEditorAndRevealsSidebar() throws {
        let model: SessionsModel = SessionsModel(library: library)
        var revealed: Int = 0
        model.revealSidebar = { revealed += 1 }
        model.newSession()
        let editing: SessionsModel.EditedSession = try XCTUnwrap(model.editing)
        XCTAssertEqual(model.selection, [editing.name])
        XCTAssertTrue(library.names.contains(editing.name))
        XCTAssertGreaterThan(revealed, 0)
    }

    /// Umbenennen im Editor: Das Sheet bleibt (gleiche Kennung) und zeigt den neuen Namen; ist die Sitzung weg, schließt es.
    func testEditorFollowsRenameAndClosesWhenSessionIsGone() throws {
        try library.save(SessionFile(), as: "A")
        let model: SessionsModel = SessionsModel(library: library)
        model.edit("A")
        let id: UUID = try XCTUnwrap(model.editing?.id)
        try model.rename("A", to: "Heim/B")
        XCTAssertEqual(model.editing?.id, id)
        XCTAssertEqual(model.editing?.name, "Heim/B")
        try library.delete(["Heim/B"], undoManager: nil)
        model.dropMissingSelection()
        XCTAssertNil(model.editing)
    }

    /// Status in der Seitenleiste: verbunden, solange mindestens ein Tab die Sitzung offen hat.
    func testConnectedSessionsCountTabs() {
        let connected: ConnectedSessions = ConnectedSessions()
        XCTAssertFalse(connected.contains("A"))
        connected.started("A")
        connected.started("A")
        connected.ended("A")
        XCTAssertTrue(connected.contains("A"))
        connected.ended("A")
        connected.ended("A")   // doppeltes Ende darf nicht unter null zählen
        XCTAssertFalse(connected.contains("A"))
        connected.started("A")
        XCTAssertTrue(connected.contains("A"))
    }
}
