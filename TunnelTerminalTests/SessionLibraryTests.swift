import TunnelTerminalCore
import XCTest
@testable import TunnelTerminal

/// Gespeicherte Sitzungen: Liste, Gruppen, Suche, Anlegen, Umbenennen, Duplizieren, Löschen, Import, Export, ⌘Z.
/// Jeder Test nutzt einen eigenen PuTTY-Ordner (RL 3.9). Daten nur mit Platzhaltern (S14).
@MainActor
final class SessionLibraryTests: XCTestCase {
    private var library: SessionLibrary!
    private var undoManager: UndoManager!

    override func setUp() async throws {
        let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        library = SessionLibrary(directory: try PuTTYDirectory(url: folder))
        undoManager = UndoManager()
        undoManager.groupsByEvent = false
    }

    private func session(host: String, user: String = "") throws -> SessionFile {
        var file: SessionFile = SessionFile()
        try file.setHostName(host)
        try file.setUserName(user)
        return file
    }

    /// Ein Bearbeitungsschritt = ein Eintrag für ⌘Z (in der App bündelt AppKit pro Ereignis).
    private func step<Result>(_ body: () throws -> Result) rethrows -> Result {
        undoManager.beginUndoGrouping()
        defer { undoManager.endUndoGrouping() }
        return try body()
    }

    func testListsSavedSessionsWithoutQuickSessions() throws {
        try library.save(try session(host: "server.example"), as: "B")
        try library.save(try session(host: "192.0.2.1"), as: "Heim/A")
        try library.save(SessionFile(), as: SessionName.defaultSettings)
        try library.directory.write(SessionFile(), sessionName: AppIdentity.quickSessionPrefix + "x")
        library.reload()
        XCTAssertEqual(library.names, ["B", "Default Settings", "Heim/A"])
        XCTAssertEqual(library.groups(matching: "").map(\.title), [nil, "Heim"])
        XCTAssertEqual(library.groups(matching: "").map(\.names), [["B"], ["Heim/A"]])
    }

    func testSearchesNameAndHost() throws {
        try library.save(try session(host: "server.example"), as: "Arbeit/Web")
        try library.save(try session(host: "192.0.2.7"), as: "Heim/NAS")
        XCTAssertEqual(library.groups(matching: "nas").flatMap(\.names), ["Heim/NAS"])
        XCTAssertEqual(library.groups(matching: "SERVER.ex").flatMap(\.names), ["Arbeit/Web"])
        XCTAssertEqual(library.groups(matching: "arbeit").flatMap(\.names), ["Arbeit/Web"])
        XCTAssertTrue(library.groups(matching: "nichts").isEmpty)
    }

    func testCreateStartsFromDefaultSettingsAndCanBeUndone() throws {
        try library.save(try session(host: "", user: "test"), as: SessionName.defaultSettings)
        let first: String = try step { try library.create(undoManager: undoManager) }
        let second: String = try step { try library.create(undoManager: undoManager) }
        XCTAssertEqual([first, second], ["Neue Sitzung", "Neue Sitzung 2"])
        XCTAssertEqual(library.file(named: first)?.userName, "test")
        undoManager.undo()
        XCTAssertEqual(library.names, ["Default Settings", "Neue Sitzung"])
    }

    func testCreateWithoutDefaultSettingsUsesSSHAndModernTerminal() throws {
        let name: String = try library.create(undoManager: nil)
        let file: SessionFile = try XCTUnwrap(library.file(named: name))
        XCTAssertEqual(file.connectionProtocol, .ssh)
        XCTAssertEqual(file.portNumber, 22)
        XCTAssertEqual(file.terminalType, "xterm-256color")
    }

    func testRenameWithUndoAndRedo() throws {
        let file: SessionFile = try session(host: "server.example")
        try library.save(file, as: "A")
        try library.save(SessionFile(), as: "Belegt")
        try step { try library.rename("A", to: "Heim/A2", undoManager: undoManager) }
        XCTAssertEqual(library.names, ["Belegt", "Heim/A2"])
        XCTAssertEqual(library.file(named: "Heim/A2"), file)
        undoManager.undo()
        XCTAssertEqual(library.names, ["A", "Belegt"])
        undoManager.redo()
        XCTAssertEqual(library.names, ["Belegt", "Heim/A2"])

        XCTAssertThrowsError(try library.rename("Heim/A2", to: "belegt", undoManager: nil)) {
            XCTAssertEqual($0 as? InputError, .nameTaken)
        }
        XCTAssertThrowsError(try library.rename("Heim/A2", to: "Default Settings", undoManager: nil)) {
            XCTAssertEqual($0 as? InputError, .reservedName)
        }
        XCTAssertThrowsError(try library.rename("Heim/A2", to: "-x", undoManager: nil))
        XCTAssertThrowsError(try library.rename(SessionName.defaultSettings, to: "X", undoManager: nil))
        try library.rename("Heim/A2", to: "heim/a2", undoManager: nil)
        XCTAssertEqual(library.names, ["Belegt", "heim/a2"])
    }

    func testDuplicateAndDeleteWithUndo() throws {
        let file: SessionFile = try session(host: "server.example", user: "test")
        try library.save(file, as: "A")
        let copies: [String] = try step { try library.duplicate(["A"], undoManager: undoManager) }
        XCTAssertEqual(copies, ["A 2"])
        XCTAssertEqual(library.file(named: "A 2"), file)
        try step { try library.delete(["A", "A 2"], undoManager: undoManager) }
        XCTAssertEqual(library.names, [])
        undoManager.undo()
        XCTAssertEqual(library.names, ["A", "A 2"])
        XCTAssertEqual(library.file(named: "A"), file)
        undoManager.redo()
        XCTAssertEqual(library.names, [])
        undoManager.undo()
        undoManager.undo()
        XCTAssertEqual(library.names, ["A"])
    }

    func testImportWithUndoRestoresPreviousDefaultSettings() throws {
        let ownDefaults: SessionFile = try session(host: "", user: "test")
        try library.save(ownDefaults, as: SessionName.defaultSettings)
        try library.save(SessionFile(), as: "Server")
        let imported: [ImportedSession] = [
            ImportedSession(name: SessionName.defaultSettings, file: try session(host: "192.0.2.1")),
            ImportedSession(name: "Server", file: try session(host: "server.example"))
        ]
        let candidates: [ImportCandidate] = SessionImport.candidates(for: imported, existingNames: library.names,
                                                                      reservedPrefix: AppIdentity.quickSessionPrefix)
        let names: [String] = try step { try library.importSessions(candidates, undoManager: undoManager) }
        XCTAssertEqual(names, ["Default Settings", "Server 2"])
        XCTAssertEqual(library.file(named: SessionName.defaultSettings)?.hostName, "192.0.2.1")
        XCTAssertEqual(library.file(named: "Server 2")?.hostName, "server.example")
        undoManager.undo()
        XCTAssertEqual(library.names, ["Default Settings", "Server"])
        XCTAssertEqual(library.file(named: SessionName.defaultSettings), ownDefaults)
    }

    func testImportSkipsCandidatesWithProblems() throws {
        let candidates: [ImportCandidate] = SessionImport.candidates(
            for: [ImportedSession(name: "-x", file: SessionFile())], existingNames: [],
            reservedPrefix: AppIdentity.quickSessionPrefix)
        XCTAssertEqual(try library.importSessions(candidates, undoManager: nil), [])
        XCTAssertEqual(library.names, [])
    }

    func testExportRoundTrips() throws {
        try library.save(try session(host: "server.example", user: "test"), as: "A")
        try library.save(try session(host: "192.0.2.1"), as: "Heim/B")
        let registry: [ImportedSession] = try RegistryFile.sessions(from: library.registryExport(of: ["A", "Heim/B"]))
        XCTAssertEqual(registry.map(\.name), ["A", "Heim/B"])
        XCTAssertEqual(registry.map(\.file), [library.file(named: "A"), library.file(named: "Heim/B")])

        let target: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: target) }
        try library.exportFolder(of: ["Heim/B"], to: target)
        let folder: PuTTYFolder.Reading = try PuTTYFolder.sessions(in: target)
        XCTAssertEqual(folder.sessions.map(\.name), ["Heim/B"])
        XCTAssertEqual(folder.sessions.first?.file, library.file(named: "Heim/B"))
    }

    func testExportFolderRefusesForeignFolders() throws {
        try library.save(SessionFile(), as: "A")
        let target: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: target) }
        try Data("x".utf8).write(to: target.appendingPathComponent("Notiz.txt"))
        XCTAssertThrowsError(try library.exportFolder(of: ["A"], to: target)) {
            XCTAssertEqual($0 as? InputError, .notAPuTTYFolder)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.appendingPathComponent("sessions").path))
    }

    /// Nach ⌘Z darf der Editor nicht die alte Sitzung weiterbearbeiten (sonst entstünde sie beim Tippen neu).
    func testUndoRebuildsEditorAndDropsMissingSelection() throws {
        let model: SessionsModel = SessionsModel(library: library)
        model.undoManager = { [undoManager] in undoManager }
        try library.save(try session(host: "server.example"), as: "A")
        model.selection = ["A"]
        try step { try model.rename("A", to: "B") }
        XCTAssertEqual(model.selection, ["B"])
        let before: Int = library.revision
        undoManager.undo()
        XCTAssertGreaterThan(library.revision, before)
        XCTAssertNil(model.editableFile(named: "B"))
        model.dropMissingSelection()
        XCTAssertEqual(model.selection, [])
        XCTAssertNotNil(model.editableFile(named: "A"))
    }

    /// Ungespeicherte Standardeinstellungen zeigen dieselbe Vorlage, die neue Sitzungen bekommen.
    func testDefaultSettingsEditorStartsFromTemplate() throws {
        let model: SessionsModel = SessionsModel(library: library)
        XCTAssertEqual(model.editableFile(named: SessionName.defaultSettings)?.terminalType, "xterm-256color")
        XCTAssertEqual(model.editableFile(named: SessionName.defaultSettings), library.template())
    }

    func testGroupsSortLikeFinder() throws {
        for name in ["Zeta", "alpha", "Ärger", "Heim/b", "Heim/A", "büro/x"] { try library.save(SessionFile(), as: name) }
        let groups: [SessionLibrary.Group] = library.groups(matching: "")
        XCTAssertEqual(groups.map(\.title), [nil, "büro", "Heim"])
        XCTAssertEqual(groups[0].names, ["alpha", "Ärger", "Zeta"])
        XCTAssertEqual(groups[2].names, ["Heim/A", "Heim/b"])
    }

    func testRegistryExportFileIsPrivate() throws {
        try library.save(try session(host: "server.example"), as: "A")
        let target: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString).reg")
        addTeardownBlock { try? FileManager.default.removeItem(at: target) }
        try Data("alt".utf8).write(to: target)
        try library.writeRegistryExport(of: ["A"], to: target)
        let mode: Int = try FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions] as? Int ?? 0
        XCTAssertEqual(mode & 0o777, 0o600)
        XCTAssertEqual(try RegistryFile.sessions(from: Data(contentsOf: target)).map(\.name), ["A"])
    }

    /// Eine vorhandene, aber nicht lesbare Datei wird nicht gelöscht (sonst wäre ⌘Z wirkungslos).
    func testDeleteRefusesUnreadableSessions() throws {
        let sessions: URL = library.directory.url.appendingPathComponent("sessions")
        try Data(count: PuTTYDirectory.maximumSessionSize + 1).write(to: sessions.appendingPathComponent("Gross"))
        library.reload()
        XCTAssertThrowsError(try library.delete(["Gross"], undoManager: nil))
        XCTAssertTrue(library.directory.exists(sessionNamed: "Gross"))
    }

    func testDuplicateRefusesTooLongNames() throws {
        let name: String = String(repeating: "x", count: 199)
        try library.save(SessionFile(), as: name)
        XCTAssertThrowsError(try library.duplicate([name], undoManager: nil))
    }
}
