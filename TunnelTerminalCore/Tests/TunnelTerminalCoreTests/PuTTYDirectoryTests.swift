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
}
