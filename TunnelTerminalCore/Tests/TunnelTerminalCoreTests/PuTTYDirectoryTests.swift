import Foundation
import Testing
@testable import TunnelTerminalCore

/// Eigener PuTTY-Ordner der App (Plan Abschnitt 3): Ordner 0700, Dateien 0600 (M0, Vorschlag 3).
@Suite("PuTTY-Ordner")
struct PuTTYDirectoryTests {
    private func temporaryDirectory() throws -> URL {
        let url: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TunnelTerminalCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func mode(_ url: URL) throws -> Int {
        let attributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? Int ?? -1) & 0o777
    }

    @Test("Legt Ordner mit 0700 an und schreibt Sitzungen mit 0600")
    func createsPrivateFiles() throws {
        let base: URL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: base.appendingPathComponent("putty"))
        #expect(try mode(directory.url) == 0o700)
        #expect(try mode(directory.url.appendingPathComponent("sessions")) == 0o700)

        var session: SessionFile = SessionFile()
        try session.setValue("server.example", forKey: "HostName")
        try directory.write(session, sessionName: "Test Sitzung")
        let written: URL = directory.url.appendingPathComponent("sessions/Test%20Sitzung")
        #expect(try mode(written) == 0o600)
        #expect(try Data(contentsOf: written) == session.contents)
        // Kein Rest der Zwischendatei
        #expect(try FileManager.default.contentsOfDirectory(atPath: written.deletingLastPathComponent().path) == ["Test%20Sitzung"])
    }

    @Test("Zu offene vorhandene Ordner werden auf 0700 gesetzt")
    func tightensExistingDirectories() throws {
        let base: URL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let url: URL = base.appendingPathComponent("putty")
        try FileManager.default.createDirectory(at: url.appendingPathComponent("sessions"), withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o755])
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        let directory: PuTTYDirectory = try PuTTYDirectory(url: url)
        #expect(try mode(directory.url) == 0o700)
        #expect(try mode(url.appendingPathComponent("sessions")) == 0o700)
    }

    @Test("Überschreiben und Entfernen; Aufräumen nur mit Präfix")
    func overwriteAndRemove() throws {
        let base: URL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: base.appendingPathComponent("putty"))
        var first: SessionFile = SessionFile()
        try first.setValue("1", forKey: "A")
        try directory.write(first, sessionName: "TunnelTerminal-Schnell-1")
        try directory.write(first, sessionName: "TunnelTerminal-Schnell-2")
        try directory.write(first, sessionName: "Eigene")
        var second: SessionFile = SessionFile()
        try second.setValue("2", forKey: "A")
        try directory.write(second, sessionName: "TunnelTerminal-Schnell-1")
        let sessions: URL = directory.url.appendingPathComponent("sessions")
        #expect(try Data(contentsOf: sessions.appendingPathComponent("TunnelTerminal-Schnell-1")) == second.contents)

        directory.removeSession(named: "TunnelTerminal-Schnell-1")
        // Rest eines abgebrochenen Schreibens (Absturz zwischen open und rename)
        #expect(FileManager.default.createFile(atPath: sessions.appendingPathComponent(".schreiben-alt").path, contents: Data()))
        directory.removeSessions(withPrefix: "TunnelTerminal-Schnell-")
        #expect(directory.sessionFileNames() == ["Eigene"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: sessions.path) == ["Eigene"])
    }

    @Test("Sitzungsnamen mit Pfadanteilen sind unschädlich")
    func pathTraversalIsEscaped() throws {
        let base: URL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: base.appendingPathComponent("putty"))
        try directory.write(SessionFile(), sessionName: "../../x")
        #expect(FileManager.default.fileExists(atPath: directory.url.appendingPathComponent("sessions/..%2F..%2Fx").path))
    }

    @Test("Gespeicherte Sitzungen auflisten: zurückübersetzte Namen, ohne Zwischendateien und Unlesbares")
    func listsSessionNames() throws {
        let base: URL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: base.appendingPathComponent("putty"))
        for name in ["Heim/Server", "Mein Server", SessionName.defaultSettings] {
            try directory.write(SessionFile(), sessionName: name)
        }
        let sessions: URL = directory.url.appendingPathComponent("sessions")
        #expect(FileManager.default.createFile(atPath: sessions.appendingPathComponent(".schreiben-x").path, contents: Data()))
        #expect(FileManager.default.createFile(atPath: sessions.appendingPathComponent("kaputt%FF").path, contents: Data()))
        #expect(directory.sessionNames() == ["Default Settings", "Heim/Server", "Mein Server"])
    }

    @Test("Lesen liefert die Datei byte-gleich; fehlende und zu große Dateien werfen")
    func readsSessions() throws {
        let base: URL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: base.appendingPathComponent("putty"))
        let original: SessionFile = try SessionFile(contents: Data("HostName=server.example\r\nUnbekannt=x\n".utf8))
        try directory.write(original, sessionName: "Heim/Server")
        #expect(try directory.read(sessionNamed: "Heim/Server") == original)
        #expect(throws: (any Error).self) { try directory.read(sessionNamed: "Fehlt") }
        let big: URL = directory.url.appendingPathComponent("sessions/Gross")
        #expect(FileManager.default.createFile(atPath: big.path, contents: Data(count: PuTTYDirectory.maximumSessionSize + 1)))
        #expect(throws: InputError.invalidFile) { try directory.read(sessionNamed: "Gross") }
    }

    @Test("Umbenennen verschiebt die Datei samt Rechten; ein vorhandenes Ziel wird nie überschrieben")
    func renamesSessions() throws {
        let base: URL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: base.appendingPathComponent("putty"))
        var file: SessionFile = SessionFile()
        try file.setValue("server.example", forKey: "HostName")
        try directory.write(file, sessionName: "Alt")
        try directory.write(SessionFile(), sessionName: "Belegt")
        try directory.renameSession(from: "Alt", to: "Heim/Neu")
        #expect(directory.sessionNames() == ["Belegt", "Heim/Neu"])
        #expect(try directory.read(sessionNamed: "Heim/Neu") == file)
        #expect(try mode(directory.url.appendingPathComponent("sessions/Heim%2FNeu")) == 0o600)
        #expect(directory.exists(sessionNamed: "Belegt"))
        #expect(throws: (any Error).self) { try directory.renameSession(from: "Heim/Neu", to: "Belegt") }
        #expect(try directory.read(sessionNamed: "Belegt") == SessionFile())
        #expect(try directory.read(sessionNamed: "Heim/Neu") == file)
    }

    @Test("Umbenennen nur in Groß/klein klappt auch auf Dateisystemen ohne Unterscheidung")
    func renamesCaseOnly() throws {
        let base: URL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: base.appendingPathComponent("putty"))
        var file: SessionFile = SessionFile()
        try file.setValue("server.example", forKey: "HostName")
        try directory.write(file, sessionName: "server")
        try directory.renameSession(from: "server", to: "Server")
        #expect(directory.sessionNames() == ["Server"])
        #expect(try directory.read(sessionNamed: "Server") == file)
    }

    @Test("Nur Dateinamen, die die App selbst so schreiben würde (sonst zwei Einträge für dieselbe Sitzung)")
    func listsOnlyCanonicalFileNames() throws {
        let base: URL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: base.appendingPathComponent("putty"))
        let sessions: URL = directory.url.appendingPathComponent("sessions")
        for name in ["A", "%41", "a b", "Mein%20Server", "x%2f", ".DS_Store", ".schreiben-1"] {
            try Data("HostName=server.example\n".utf8).write(to: sessions.appendingPathComponent(name))
        }
        #expect(directory.sessionNames() == ["A", "Mein Server"])
    }
}
