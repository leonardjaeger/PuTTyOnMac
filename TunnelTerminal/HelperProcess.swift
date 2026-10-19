import Darwin
import Foundation

/// Kurzer Lauf eines PuTTY-Werkzeugs ohne Terminal (puttygen im Schlüssel-Fenster, M3): Argumentliste, eigene
/// Sitzung, nur die angegebenen Deskriptoren (wie `TerminalProcess.spawn`, S3/S8). Passphrasen kommen als Pipes ab
/// fd 3. Ausgabe und Fehlerausgabe landen zusammen in einem Text (die Leser in `PuttygenCommand` erkennen beides).
nonisolated enum HelperProcess {
    struct Result: Sendable {
        let status: Int32
        let output: String
        var succeeded: Bool { status == 0 }
    }

    /// puttygen aus dem App-Paket (gebaut von Scripts/build-putty.sh).
    static var puttygenPath: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/puttygen").path
    }

    /// Läuft außerhalb des Hauptthreads (RSA 4096 braucht etwa eine Sekunde, docs/M3-Recherche.md 2).
    /// Feste, leere Umgebung: puttygen braucht keine.
    @concurrent
    static func run(_ executable: String, _ arguments: [String], secrets: [Data] = []) async throws(TerminalProcess.Failure) -> Result {
        let null: Int32 = open("/dev/null", O_RDONLY | O_CLOEXEC)
        guard null >= 0 else { throw TerminalProcess.Failure(message: "/dev/null nicht verfügbar") }
        defer { close(null) }
        var output: [Int32] = [-1, -1]
        guard pipe(&output) == 0 else { throw TerminalProcess.Failure(message: "Keine Pipe verfügbar") }
        for end in output { _ = fcntl(end, F_SETFD, FD_CLOEXEC) }
        var descriptors: [(source: Int32, target: Int32)] = [(null, 0), (output[1], 1), (output[1], 2)]
        var secretPipes: [Int32] = []
        defer { secretPipes.forEach { close($0) } }
        do {
            for (index, secret) in secrets.enumerated() {
                let readEnd: Int32 = try TerminalProcess.pipe(holding: secret)
                secretPipes.append(readEnd)
                descriptors.append((readEnd, Int32(3 + index)))
            }
            let child: pid_t = try TerminalProcess.spawn(executable: executable, arguments: arguments, environment: [],
                                                         descriptors: descriptors)
            close(output[1])
            output[1] = -1
            let text: Data = FileHandle(fileDescriptor: output[0], closeOnDealloc: false).readDataToEndOfFile()
            close(output[0])
            var status: Int32 = 0
            while waitpid(child, &status, 0) < 0 && errno == EINTR {}
            let exitCode: Int32 = (status & 0x7F) == 0 ? (status >> 8) & 0xFF : 128 + (status & 0x7F)
            return Result(status: exitCode, output: String(decoding: text, as: UTF8.self))
        } catch {
            if output[1] >= 0 { close(output[1]) }
            close(output[0])
            throw error
        }
    }
}
