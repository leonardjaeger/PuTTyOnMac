import Foundation

/// Der eigene PuTTY-Ordner der App (`PUTTYDIR`, Plan Abschnitt 3): Ordner `0700`, Sitzungsdateien `0600`.
public struct PuTTYDirectory: Sendable {
    public let url: URL

    private var sessions: URL { url.appendingPathComponent("sessions", isDirectory: true) }
    private static let temporaryPrefix: String = ".schreiben-"

    /// Legt den Ordner und `sessions/` an und setzt beide auf `0700` (auch wenn sie schon da waren).
    public init(url: URL) throws {
        self.url = url
        let manager: FileManager = FileManager.default
        for directory in [url, sessions] {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
            try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }
    }

    /// Schreibt eine Sitzung atomar (Zwischendatei mit `0600`, dann umbenennen), damit plink nie eine halbe Datei liest.
    public func write(_ file: SessionFile, sessionName: String) throws {
        let target: URL = sessions.appendingPathComponent(SessionFile.fileName(forSessionNamed: sessionName))
        let temporary: URL = sessions.appendingPathComponent(Self.temporaryPrefix + UUID().uuidString)
        let descriptor: Int32 = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle: FileHandle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: file.contents)
            try handle.synchronize()
            try handle.close()
            guard rename(temporary.path, target.path) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        } catch {
            unlink(temporary.path)
            throw error
        }
    }

    public func removeSession(named sessionName: String) {
        unlink(sessions.appendingPathComponent(SessionFile.fileName(forSessionNamed: sessionName)).path)
    }

    /// Dateinamen in `sessions/` (kodiert wie bei PuTTY, siehe `SessionFile.fileName(forSessionNamed:)`).
    public func sessionFileNames() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: sessions.path)) ?? []
    }

    /// Räumt liegengebliebene Sitzungen eines Präfixes auf (z. B. Schnellverbindungen nach einem Absturz),
    /// dazu halb geschriebene Zwischendateien (sie enthalten Server und Benutzer).
    public func removeSessions(withPrefix prefix: String) {
        let encoded: String = SessionFile.fileName(forSessionNamed: prefix)
        for name in sessionFileNames() where name.hasPrefix(encoded) || name.hasPrefix(Self.temporaryPrefix) {
            unlink(sessions.appendingPathComponent(name).path)
        }
    }
}
