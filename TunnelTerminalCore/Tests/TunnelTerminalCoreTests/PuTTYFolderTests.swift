import Foundation
import Testing
@testable import TunnelTerminalCore

/// Import aus einem fremden PuTTY-Ordner (`~/.putty`, `~/.config/putty`): nur lesen, nichts verändern.
@Suite("Fremder PuTTY-Ordner")
struct PuTTYFolderTests {
    private func makeFolder() throws -> URL {
        let url: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TunnelTerminalCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url.appendingPathComponent("sessions"), withIntermediateDirectories: true)
        return url
    }

    private func put(_ text: String, _ fileName: String, in folder: URL) throws {
        try Data(text.utf8).write(to: folder.appendingPathComponent("sessions").appendingPathComponent(fileName))
    }

    @Test("Liest alle Sitzungen byte-gleich, sortiert; Ordner und Rechte bleiben unverändert")
    func readsSessions() throws {
        let folder: URL = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try put("HostName=server.example\nUnbekannt=1\r\n", "Heim%2FServer%20A", in: folder)
        try put("HostName=192.0.2.1\n", "Default%20Settings", in: folder)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)

        let result: PuTTYFolder.Reading = try PuTTYFolder.sessions(in: folder)
        #expect(result.sessions.map(\.name) == ["Default Settings", "Heim/Server A"])
        #expect(result.sessions[1].file.contents == Data("HostName=server.example\nUnbekannt=1\r\n".utf8))
        #expect(result.unreadable.isEmpty)
        let mode: Int = try FileManager.default.attributesOfItem(atPath: folder.path)[.posixPermissions] as? Int ?? 0
        #expect(mode & 0o777 == 0o755)
        // Auch wenn der Ordner „sessions“ selbst gewählt wird
        #expect(try PuTTYFolder.sessions(in: folder.appendingPathComponent("sessions")).sessions.count == 2)
    }

    @Test("Verweise, zu große Dateien, NUL-Bytes und kaputte Namen werden nicht gelesen, sondern gemeldet")
    func reportsUnreadable() throws {
        let folder: URL = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let sessions: URL = folder.appendingPathComponent("sessions")
        try put("HostName=server.example\n", "Gut", in: folder)
        try FileManager.default.createSymbolicLink(at: sessions.appendingPathComponent("Verweis"),
                                                   withDestinationURL: sessions.appendingPathComponent("Gut"))
        try Data(count: PuTTYDirectory.maximumSessionSize + 1).write(to: sessions.appendingPathComponent("Gross"))
        try put("Host\u{0}Name=x\n", "Nul", in: folder)
        try put("HostName=x\n", "Kaputt%ZZ", in: folder)
        try FileManager.default.createDirectory(at: sessions.appendingPathComponent("Ordner"), withIntermediateDirectories: false)

        let result: PuTTYFolder.Reading = try PuTTYFolder.sessions(in: folder)
        #expect(result.sessions.map(\.name) == ["Gut"])
        #expect(result.unreadable == ["Gross", "Kaputt%ZZ", "Nul", "Ordner", "Verweis"])
    }

    @Test("Ein Ordner ohne „sessions“ ist keine PuTTY-Quelle")
    func rejectsOtherFolders() throws {
        let folder: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TunnelTerminalCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("HostName=x\n".utf8).write(to: folder.appendingPathComponent("Datei"))
        #expect(throws: InputError.notAPuTTYFolder) { try PuTTYFolder.sessions(in: folder) }
    }
}
