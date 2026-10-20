import Darwin
import Foundation
import TunnelTerminalCore

/// Sitzungsprotokoll (Plan M4): Die App schreibt die Ausgabe der Sitzung selbst mit, weil plink ohne Terminal nichts
/// protokolliert (Machbarkeit M4, entschieden am 19.10.2026). Nur was ankommt: Getipptes nur, soweit der Server es
/// anzeigt (Echo) – verdeckt getippte Passwörter nicht. Datei neu und nur für den Benutzer (0600, `O_EXCL`, kein Symlink).
/// Höchstens `limit` Bytes, damit ein Server mit endloser Ausgabe nicht die Platte füllt.
final class SessionLogWriter {
    let url: URL
    private let handle: FileHandle
    private let queue: DispatchQueue = DispatchQueue(label: "\(AppIdentity.logSubsystem).protokoll")
    private var written: Int = 0
    static let limit: Int = 1 << 30   // 1 GiB

    static var folder: URL {
        URL.libraryDirectory.appending(path: "Logs/\(AppIdentity.name)", directoryHint: .isDirectory)
    }

    nonisolated struct Failure: Error {
        let message: String
    }

    init(sessionName: String, folder: URL = SessionLogWriter.folder, date: Date = .now) throws(Failure) {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        } catch {
            throw Failure(message: "Protokollordner nicht anlegbar")
        }
        let name: String = SessionLogName.fileName(sessionName: sessionName, date: date)
        var descriptor: Int32 = -1
        var candidate: URL = folder
        // Zwei Tabs derselben Sitzung in derselben Sekunde: Nummer anhängen
        for number in 1...9 where descriptor < 0 {
            let file: String = number == 1 ? name : "\(name.dropLast(4)) \(number).log"
            candidate = folder.appending(path: file, directoryHint: .notDirectory)
            descriptor = open(candidate.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
            if descriptor < 0 && errno != EEXIST { break }
        }
        guard descriptor >= 0 else { throw Failure(message: String(cString: strerror(errno))) }
        url = candidate
        handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }

    /// Schreibt im Hintergrund, damit viel Ausgabe das Terminal nicht bremst. `false`, sobald die Grenze erreicht ist
    /// (dann wird nichts mehr geschrieben).
    @discardableResult
    func write(_ bytes: ArraySlice<UInt8>, limit: Int = SessionLogWriter.limit) -> Bool {
        guard written + bytes.count <= limit else { return false }
        written += bytes.count
        let data: Data = Data(bytes)
        let handle: FileHandle = handle
        // shortcut: Schreibfehler (z. B. volle Platte) gehen verloren; bei Bedarf in der Statuszeile melden
        queue.async { try? handle.write(contentsOf: data) }
        return true
    }

    func close() {
        let handle: FileHandle = handle
        queue.async { try? handle.close() }
    }
}
