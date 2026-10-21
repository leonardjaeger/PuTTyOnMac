import Foundation

/// Ein fremder PuTTY-Ordner als Importquelle (`~/.putty`, `~/.config/putty` oder darin `sessions`).
/// Wird nur gelesen: anders als `PuTTYDirectory` legt er nichts an und ändert keine Rechte.
public enum PuTTYFolder {
    public struct Reading: Equatable, Sendable {
        public var sessions: [ImportedSession]
        /// Dateinamen, die nicht gelesen wurden (Verweise, Ordner, zu groß, NUL-Bytes, ungültige Kodierung).
        public var unreadable: [String]
    }

    /// Liest alle Sitzungen, sortiert nach Namen. Höchstens `limit` Bytes insgesamt (wie beim `.reg`-Import), danach
    /// gelten die übrigen Dateien als nicht gelesen: Der Import läuft auf dem Hauptthread (Härtung, Code-Review R-3).
    public static func sessions(in url: URL, limit: Int = RegistryFile.maximumSize) throws(InputError) -> Reading {
        let manager: FileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let nested: URL = url.appendingPathComponent("sessions", isDirectory: true)
        let folder: URL
        if manager.fileExists(atPath: nested.path, isDirectory: &isDirectory), isDirectory.boolValue {
            folder = nested
        } else if url.lastPathComponent == "sessions" {
            folder = url
        } else {
            throw .notAPuTTYFolder
        }
        guard let fileNames = try? manager.contentsOfDirectory(atPath: folder.path) else { throw .notAPuTTYFolder }
        var reading: Reading = Reading(sessions: [], unreadable: [])
        var total: Int = 0
        for fileName in fileNames.sorted() {
            guard total <= limit, let name = SessionName.decode(fileName: fileName),
                  let file = try? PuTTYDirectory.readSession(at: folder.appendingPathComponent(fileName)) else {
                reading.unreadable.append(fileName)
                continue
            }
            total += file.contents.count
            guard total <= limit else {   // ab hier wird nichts mehr gelesen
                reading.unreadable.append(fileName)
                continue
            }
            reading.sessions.append(ImportedSession(name: name, file: file))
        }
        reading.sessions.sort { $0.name < $1.name }
        return reading
    }
}
