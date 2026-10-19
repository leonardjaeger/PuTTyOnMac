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
        try writeAtomically(file.contents, to: fileURL(sessionName), temporaryIn: sessions)
    }

    /// Zwischendatei mit `0600` im selben Ordner, dann umbenennen.
    private func writeAtomically(_ data: Data, to target: URL, temporaryIn folder: URL) throws {
        let temporary: URL = folder.appendingPathComponent(Self.temporaryPrefix + UUID().uuidString)
        let descriptor: Int32 = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle: FileHandle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: data)
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
        try SessionFile(contents: readRegularFile(at: url, limit: maximumSessionSize))
    }

    /// Nur reguläre Dateien (keine Verweise) bis `limit` Bytes.
    private static func readRegularFile(at url: URL, limit: Int) throws -> Data {
        let attributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? Int, size <= limit else { throw InputError.invalidFile }
        return try Data(contentsOf: url)
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

    // MARK: - Bekannte Hostschlüssel (`sshhostkeys`, schreibt plink)

    private var hostKeysURL: URL { url.appendingPathComponent("sshhostkeys") }

    /// Liest `sshhostkeys`; fehlt die Datei, ist die Liste leer. Nur eine reguläre Datei (kein Verweis).
    public func knownHostKeys() throws -> KnownHostKeys {
        guard Self.entryExists(at: hostKeysURL) else {
            return KnownHostKeys(contents: Data())
        }
        return KnownHostKeys(contents: try Self.readRegularFile(at: hostKeysURL, limit: KnownHostKeys.maximumSize))
    }

    /// Entfernt Einträge (z. B. nach einer Neuinstallation des Servers): plink fragt beim nächsten Verbinden wieder.
    /// Schreibt atomar mit `0600`, damit plink nie eine halbe Datei liest.
    public func removeKnownHostKeys(_ ids: Set<String>) throws {
        var keys: KnownHostKeys = try knownHostKeys()
        keys.remove(ids)
        try writeAtomically(keys.contents, to: hostKeysURL, temporaryIn: url)
    }

    /// Gibt es den Eintrag – ohne Verweisen zu folgen (ein Verweis wird dann beim Lesen abgelehnt)?
    private static func entryExists(at url: URL) -> Bool {
        var status: stat = stat()
        return lstat(url.path, &status) == 0
    }
}
