import Foundation

/// Der eigene PuTTY-Ordner der App (`PUTTYDIR`, Plan Abschnitt 3): Ordner `0700`, Sitzungsdateien `0600`.
public struct PuTTYDirectory: Sendable {
    public let url: URL

    private var sessions: URL { url.appendingPathComponent("sessions", isDirectory: true) }
    private static let temporaryPrefix: String = ".schreiben-"
    /// Obergrenze für eine Sitzungsdatei: PuTTY-Dateien haben wenige KiB; schützt vor riesigen fremden Dateien.
    public static let maximumSessionSize: Int = 1 << 20

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
        let target: URL = fileURL(sessionName)
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
        unlink(fileURL(sessionName).path)
    }

    /// Namen aller Sitzungen, sortiert; ohne Zwischendateien und ohne Dateinamen, die die App so nie schreiben würde.
    public func sessionNames() -> [String] {
        sessionFileNames().filter { !$0.hasPrefix(".") }.compactMap { fileName in
            // Versteckte Dateien (Zwischendateien „.schreiben-…“, .DS_Store) sind keine Sitzungen. Nur Namen, die genau
            // so gespeichert würden: „%41“ und „A“ wären sonst zweimal die Sitzung „A“, und `-load` öffnete eine andere Datei.
            SessionName.decode(fileName: fileName).flatMap { SessionFile.fileName(forSessionNamed: $0) == fileName ? $0 : nil }
        }.sorted()
    }

    public func exists(sessionNamed sessionName: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(sessionName).path)
    }

    public func read(sessionNamed sessionName: String) throws -> SessionFile {
        try Self.readSession(at: fileURL(sessionName))
    }

    /// Benennt eine Sitzung um (Datei wird verschoben, Rechte bleiben). Ein vorhandenes Ziel wird nie überschrieben.
    /// Ändert sich nur Groß/klein, ist es auf macOS-Dateisystemen dieselbe Datei: dann direkt umbenennen.
    public func renameSession(from oldName: String, to newName: String) throws {
        guard SessionName.fileKey(oldName) == SessionName.fileKey(newName) else {
            try FileManager.default.moveItem(at: fileURL(oldName), to: fileURL(newName))
            return
        }
        // Auf Dateisystemen mit Unterscheidung könnten es zwei Dateien sein: dann nie überschreiben.
        var oldStatus: stat = stat()
        var newStatus: stat = stat()
        if lstat(fileURL(newName).path, &newStatus) == 0,
           lstat(fileURL(oldName).path, &oldStatus) != 0 || oldStatus.st_ino != newStatus.st_ino {
            throw POSIXError(.EEXIST)
        }
        guard rename(fileURL(oldName).path, fileURL(newName).path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    /// Liest eine Sitzungsdatei: nur reguläre Dateien (keine Verweise) bis `maximumSessionSize`.
    static func readSession(at url: URL) throws -> SessionFile {
        let attributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? Int, size <= maximumSessionSize else { throw InputError.invalidFile }
        return try SessionFile(contents: Data(contentsOf: url))
    }

    private func fileURL(_ sessionName: String) -> URL {
        sessions.appendingPathComponent(SessionFile.fileName(forSessionNamed: sessionName))
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
