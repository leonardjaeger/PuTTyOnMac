import AppKit
import SwiftTerm
import TunnelTerminalCore
import XCTest
@testable import TunnelTerminal

/// M4 Terminal-Komfort: Profile, Einfügen mit Rückfrage (S10), Tasten, Titel, Protokoll. Eigener PuTTY-Ordner und eigene
/// Einstellungen je Test (RL 3.9), nur Platzhalter (S14).
@MainActor
final class TerminalComfortTests: XCTestCase {
    private var library: SessionLibrary!
    private var defaults: UserDefaults!
    private var profiles: ProfileStore!
    private var folder: URL!

    override func setUp() async throws {
        let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        self.folder = folder
        library = SessionLibrary(directory: try PuTTYDirectory(url: folder.appendingPathComponent("putty")))
        let suite: String = "TunnelTerminalTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        profiles = ProfileStore(defaults: defaults)
    }

    private func makeWindow() -> ConnectionWindowController {
        let controller: ConnectionWindowController = ConnectionWindowController(
            library: library, connected: ConnectedSessions(), profiles: profiles)
        addTeardownBlock { @MainActor in controller.window?.close() }
        controller.showWindow(nil)
        return controller
    }

    /// Gespeicherte Raw-Sitzung auf einen lauschenden Test-Socket; gibt die angenommene Gegenseite zurück.
    private func connect(_ controller: ConnectionWindowController, session file: SessionFile = SessionFile())
        throws -> Int32 {
        let server: (descriptor: Int32, port: Int) = try localSocket(listening: true)
        addTeardownBlock { close(server.descriptor) }
        var session: SessionFile = file
        session.setConnectionProtocol(.raw)
        try session.setHostName("127.0.0.1")
        try session.setPortNumber(server.port)
        try library.save(session, as: "Test")
        controller.open(.savedSession("Test"))
        let client: Int32 = try accept(on: server.descriptor)
        addTeardownBlock { close(client) }
        XCTAssertTrue(controller.isConnected)
        return client
    }

    // MARK: Profile

    func testProfileStoreKeepsNamesUniqueAndStandard() throws {
        let changed: XCTestExpectation = expectation(forNotification: ProfileStore.didChange, object: profiles)
        let copy: TerminalProfile = profiles.add(copying: .standard)
        wait(for: [changed], timeout: 1)
        XCTAssertEqual(copy.name, "Standard Kopie")
        XCTAssertEqual(profiles.add(copying: .standard).name, "Standard Kopie 2")
        var renamed: TerminalProfile = copy
        renamed.name = "Standard"
        XCTAssertThrowsError(try profiles.update(renamed)) { XCTAssertEqual($0 as? InputError, .profileNameTaken) }
        renamed.name = "Dunkel"
        renamed.fontSize = 500
        try profiles.update(renamed)
        XCTAssertEqual(profiles.profile(id: copy.id).fontSize, TerminalProfile.fontSizes.upperBound)
        profiles.remove(id: TerminalProfile.standardID)
        XCTAssertEqual(profiles.profiles.first?.id, TerminalProfile.standardID)
        // gespeichert: eine neue Liste aus denselben Einstellungen ist gleich
        XCTAssertEqual(ProfileStore(defaults: defaults).profiles, profiles.profiles)
        XCTAssertEqual(profiles.profile(id: UUID()).id, TerminalProfile.standardID)
    }

    /// Prüfpunkt M4: Profil „Dunkel, 14 pt, 10 000 Zeilen“ einer Sitzung zuweisen; Änderungen wirken im offenen Tab.
    func testSessionProfileAppliesToTerminalAndFollowsChanges() throws {
        var dark: TerminalProfile = profiles.add(copying: .standard)
        dark.name = "Dunkel"
        dark.colorScheme = .dark
        dark.fontSize = 14
        dark.scrollbackLines = 10_000
        try profiles.update(dark)
        var session: SessionFile = SessionFile()
        try session.setProfileID(dark.id)
        let controller: ConnectionWindowController = makeWindow()
        _ = try connect(controller, session: session)
        let terminal: AppTerminalView = try XCTUnwrap(controller.terminal)
        XCTAssertEqual(terminal.font.pointSize, 14)
        XCTAssertEqual(terminal.nativeBackgroundColor.usingColorSpace(.sRGB)?.redComponent ?? 0, 30 / 255, accuracy: 0.01)
        dark.fontSize = 16
        try profiles.update(dark)
        XCTAssertEqual(terminal.font.pointSize, 16)
        profiles.remove(id: dark.id)   // gelöscht: zurück zum Standardprofil
        XCTAssertEqual(terminal.font.pointSize, 13)
    }

    // MARK: Einfügen (S10)

    /// Was das Terminal an plink schicken würde. plink 0.85 schaltet bei Raw das Terminal nie roh (`ldisc_create` vor
    /// `seat_echoedit_update(1, 1)` in unix/plink.c) und puffert Zeilen – deshalb hier statt am Socket gemessen.
    private final class SentBytes: TerminalViewDelegate {
        var bytes: [UInt8] = []
        /// SwiftTerm reicht Gesendetes über die Hauptschleife weiter: kurz laufen lassen.
        var text: String {
            RunLoop.main.run(until: Date.now.addingTimeInterval(0.3))
            return String(decoding: bytes, as: UTF8.self)
        }
        func send(source: TerminalView, data: ArraySlice<UInt8>) { bytes.append(contentsOf: data) }
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func scrolled(source: TerminalView, position: Double) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }

    private func recordSent(_ controller: ConnectionWindowController) throws -> SentBytes {
        let sent: SentBytes = SentBytes()
        try XCTUnwrap(controller.terminal).terminalDelegate = sent
        addTeardownBlock { @MainActor in _ = sent }
        return sent
    }

    func testPasteWithLineBreakWaitsForConfirmation() throws {
        let controller: ConnectionWindowController = makeWindow()
        _ = try connect(controller)
        let sent: SentBytes = try recordSent(controller)
        controller.requestPaste("echo eins")
        XCTAssertEqual(sent.text, "echo eins")
        XCTAssertFalse(controller.isPastePending)

        sent.bytes = []
        controller.requestPaste("rm -r x\necho zwei")
        XCTAssertTrue(controller.isPastePending)
        XCTAssertTrue(controller.terminal?.isPastePending == true)
        XCTAssertEqual(sent.text, "")
        controller.requestPaste("noch mehr")   // während der Rückfrage kein zweites Einfügen
        controller.finishPaste(true)
        // ohne Bracketed Paste macht SwiftTerm aus LF ein CR (Return)
        XCTAssertEqual(sent.text, "rm -r x\recho zwei")

        sent.bytes = []
        controller.requestPaste("echo drei\n")
        XCTAssertTrue(controller.isPastePending)
        controller.finishPaste(false)
        XCTAssertFalse(controller.isPastePending)
        XCTAssertEqual(sent.text, "")
    }

    /// Hat das Programm Bracketed Paste eingeschaltet (`CSI ? 2004 h`), kommt der Text eingerahmt an; ein eingeschleustes
    /// Ende-Zeichen (ESC) wird entschärft.
    func testBracketedPaste() throws {
        let controller: ConnectionWindowController = makeWindow()
        let client: Int32 = try connect(controller)
        let enable: [UInt8] = Array("\u{1B}[?2004h".utf8)
        XCTAssertEqual(write(client, enable, enable.count), enable.count)
        _ = received(on: client, within: 0.5)   // Ausgabe erreicht das Terminal
        let sent: SentBytes = try recordSent(controller)
        controller.requestPaste("a\nb\u{1B}[201~c")
        controller.finishPaste(true)
        XCTAssertEqual(sent.text, "\u{1B}[200~a\nb [201~c\u{1B}[201~")
    }

    /// Tasten vor SwiftTerm: Esc/⌘↩ während der Rückfrage, F1–F4 nur mit Option.
    func testKeysBeforeTerminal() throws {
        let controller: ConnectionWindowController = makeWindow()
        _ = try connect(controller)
        let terminal: AppTerminalView = try XCTUnwrap(controller.terminal)
        let window: NSWindow = try XCTUnwrap(controller.window)
        XCTAssertTrue(window.makeFirstResponder(terminal))
        terminal.settings = defaults
        func key(_ code: UInt16, _ modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                                           windowNumber: window.windowNumber, context: nil, characters: "x",
                                           charactersIgnoringModifiers: "x", isARepeat: false, keyCode: code))
        }
        var functionKeys: [Int] = []
        terminal.onFunctionKey = { functionKeys.append($0) }
        XCTAssertFalse(terminal.handleKey(try key(122)))   // F1 aus: geht an den Server
        defaults.set(true, forKey: AppSettings.functionKeys)
        XCTAssertTrue(terminal.handleKey(try key(122)))
        XCTAssertTrue(terminal.handleKey(try key(118)))
        XCTAssertFalse(terminal.handleKey(try key(122, .shift)))
        XCTAssertEqual(functionKeys, [1, 4])

        var decisions: [Bool] = []
        terminal.onPasteDecision = { decisions.append($0) }
        terminal.isPastePending = true
        XCTAssertTrue(terminal.handleKey(try key(0)))              // „a“: verschluckt
        XCTAssertTrue(terminal.handleKey(try key(36)))             // Return allein fügt nicht ein
        XCTAssertFalse(terminal.handleKey(try key(13, .command)))  // ⌘W bleibt Menübefehl
        XCTAssertTrue(terminal.handleKey(try key(53)))             // Esc
        XCTAssertTrue(terminal.handleKey(try key(36, .command)))   // ⌘↩
        XCTAssertEqual(decisions, [false, true])
    }

    // MARK: Titel, Alles kopieren, Vorschau

    func testCustomTitle() throws {
        let controller: ConnectionWindowController = makeWindow()
        controller.setCustomTitle("  Mein Tab ")
        XCTAssertEqual(controller.window?.title, "Mein Tab")
        controller.setCustomTitle("a\u{202E}b")   // Steuer- und Formatzeichen sichtbar statt wirksam
        XCTAssertEqual(controller.window?.title, "a\\u{202E}b")
        controller.setCustomTitle("")
        XCTAssertEqual(controller.window?.title, "Neue Verbindung")
    }

    func testCopyAllTrimsPadding() {
        XCTAssertEqual(ConnectionWindowController.trimmed("eins   \nzwei\n   \n\n"), "eins\nzwei")
        XCTAssertEqual(ConnectionWindowController.trimmed(""), "")
    }

    /// Vorschau der OSC-52-Anfrage: kurz, Steuerzeichen sichtbar (S11).
    func testClipboardPreview() {
        XCTAssertEqual(ConnectionWindowController.preview("a\u{1B}[31mb"), "a\\u{1B}[31mb")
        let long: String = (1...12).map(String.init).joined(separator: "\n")
        XCTAssertEqual(ConnectionWindowController.preview(long), (1...10).map(String.init).joined(separator: "\n") + " …")
        XCTAssertTrue(ConnectionWindowController.preview(String(repeating: "x", count: 500)).hasSuffix(" …"))
    }

    // MARK: Steuersequenzen vom Server (S11)

    /// OSC 52 legt nichts ohne Zustimmung in die Zwischenablage; Lesen bleibt verboten; nur eine Rückfrage zur Zeit.
    func testClipboardRequestNeedsConsent() throws {
        let controller: ConnectionWindowController = makeWindow()
        let window: NSWindow = try XCTUnwrap(controller.window)
        let terminal: TerminalView = TerminalView(frame: .zero)
        let before: Int = NSPasteboard.general.changeCount
        controller.clipboardCopy(source: terminal, content: Data("rm -rf ~".utf8))
        let sheet: NSWindow = try XCTUnwrap(window.attachedSheet, "Rückfrage fehlt")
        controller.clipboardCopy(source: terminal, content: Data("zweite".utf8))   // keine zweite Rückfrage
        XCTAssertTrue(window.attachedSheet === sheet)
        window.endSheet(sheet, returnCode: .alertFirstButtonReturn)   // „Nicht erlauben“
        XCTAssertEqual(NSPasteboard.general.changeCount, before)
        XCTAssertNil(controller.clipboardRead(source: terminal))
        controller.clipboardCopy(source: terminal, content: Data("dritte".utf8))
        XCTAssertNil(window.attachedSheet)   // einmal abgelehnt: keine weitere Rückfrage dieser Verbindung (Prüfer-Befund 3)
    }

    func testOversizedClipboardRequestIsDropped() throws {
        let controller: ConnectionWindowController = makeWindow()
        controller.clipboardCopy(source: TerminalView(frame: .zero),
                                 content: Data(count: ConnectionWindowController.clipboardLimit + 1))
        XCTAssertNil(controller.window?.attachedSheet)   // zu groß: gar nicht erst fragen
    }

    /// ⌘K leert Bildschirm und Verlauf (SwiftTerm setzt `CSI 3 J` um).
    func testClearRemovesScrollback() throws {
        let controller: ConnectionWindowController = makeWindow()
        _ = try connect(controller)
        let terminal: AppTerminalView = try XCTUnwrap(controller.terminal)
        terminal.feed(text: (1...200).map { "Zeile \($0)" }.joined(separator: "\r\n"))
        XCTAssertTrue(String(decoding: terminal.getBufferAsData(kind: .normal), as: UTF8.self).contains("Zeile 1\n"))
        controller.clearScreenAndHistory(nil)
        XCTAssertEqual(ConnectionWindowController.trimmed(String(decoding: terminal.getBufferAsData(kind: .normal),
                                                                 as: UTF8.self)), "")
    }

    /// Links: nur http/https/mailto werden angeboten, alles andere nur gemeldet (S11).
    func testLinksAreConfirmedOrRefused() throws {
        let controller: ConnectionWindowController = makeWindow()
        let window: NSWindow = try XCTUnwrap(controller.window)
        let terminal: TerminalView = TerminalView(frame: .zero)
        controller.requestOpenLink(source: terminal, link: "file:///etc/passwd", params: [:])
        let refused: NSWindow = try XCTUnwrap(window.attachedSheet)
        XCTAssertTrue(Self.texts(in: refused.contentView).contains("Dieser Link wird nicht geöffnet."))
        XCTAssertFalse(Self.texts(in: refused.contentView).contains("Öffnen"))
        window.endSheet(refused)
        controller.requestOpenLink(source: terminal, link: "https://server.example/x", params: [:])
        let asked: NSWindow = try XCTUnwrap(window.attachedSheet)
        let texts: [String] = Self.texts(in: asked.contentView)
        XCTAssertTrue(texts.contains("Link aus dem Terminal öffnen?"))
        XCTAssertTrue(texts.contains { $0.contains("https://server.example/x") })
        window.endSheet(asked, returnCode: .alertFirstButtonReturn)   // „Abbrechen“
        // Täuschung über einen Benutzerteil: das Ziel steht eigens da
        controller.requestOpenLink(source: terminal, link: "https://bank.example@boese.example/login", params: [:])
        let tricky: NSWindow = try XCTUnwrap(window.attachedSheet)
        XCTAssertTrue(Self.texts(in: tricky.contentView).contains { $0.hasPrefix("Ziel: boese.example") })
        window.endSheet(tricky, returnCode: .alertFirstButtonReturn)
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

    // MARK: Sitzungsprotokoll

    /// Die App schreibt, was ankommt, in eine neue Datei nur für den Benutzer (0600) und schließt sie am Ende.
    func testSessionLogRecordsOutput() throws {
        let server: (descriptor: Int32, port: Int) = try localSocket(listening: true)
        defer { close(server.descriptor) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: folder.appendingPathComponent("putty-log"))
        var file: SessionFile = SessionFile()
        file.setConnectionProtocol(.raw)
        try file.setHostName("127.0.0.1")
        try file.setPortNumber(server.port)
        file.setSessionLog(true)
        try directory.write(file, sessionName: "Gruppe/Protokoll")
        let logFolder: URL = folder.appendingPathComponent("Logs")
        let connection: Connection = try Connection(savedSession: "Gruppe/Protokoll", puttyDirectory: { directory },
                                                    passwords: nil, logFolder: logFolder)
        let ended: XCTestExpectation = expectation(description: "Verbindungsende")
        connection.onEnd = { _ in ended.fulfill() }
        try connection.start(columns: 80, rows: 24)
        XCTAssertNotNil(connection.log)
        let client: Int32 = try accept(on: server.descriptor)
        defer { close(client) }
        let output: [UInt8] = Array("AUSGABE-VOM-SERVER\r\n".utf8)
        XCTAssertEqual(write(client, output, output.count), output.count)
        _ = received(on: client, within: 0.5)
        connection.hangUp()
        wait(for: [ended], timeout: 10)
        XCTAssertNil(connection.log)

        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: logFolder.path)
        XCTAssertEqual(names.count, 1)
        let name: String = try XCTUnwrap(names.first)
        XCTAssertTrue(name.hasPrefix("Gruppe-Protokoll "), name)
        let url: URL = logFolder.appendingPathComponent(name)
        RunLoop.main.run(until: Date.now.addingTimeInterval(0.3))   // Schreibwarteschlange
        XCTAssertTrue(String(decoding: try Data(contentsOf: url), as: UTF8.self).contains("AUSGABE-VOM-SERVER"))
        let permissions: Int = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int)
        XCTAssertEqual(permissions, 0o600)
    }

    /// Endlose Ausgabe füllt die Platte nicht: ab der Grenze schreibt das Protokoll nichts mehr.
    func testSessionLogStopsAtLimit() throws {
        let writer: SessionLogWriter = try SessionLogWriter(sessionName: "Grenze", folder: folder.appendingPathComponent("Logs"))
        XCTAssertTrue(writer.write(ArraySlice(Array("12345".utf8)), limit: 8))
        XCTAssertFalse(writer.write(ArraySlice(Array("67890".utf8)), limit: 8))
        writer.close()
        RunLoop.main.run(until: Date.now.addingTimeInterval(0.3))
        XCTAssertEqual(try String(contentsOf: writer.url, encoding: .utf8), "12345")
    }
}
