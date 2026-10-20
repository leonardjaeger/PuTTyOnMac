import AppKit
import SwiftTerm
import XCTest
@testable import TunnelTerminal

/// Tempo bei viel Ausgabe (Plan M4, apple-skills:performance): 16 MB Text über ein PTY in `TerminalProcess`, SwiftTerm
/// und das Sitzungsprotokoll – der Teil des Wegs, der in der App läuft (plink selbst misst build/m4/tempo.sh).
/// Gemessen werden Durchsatz und die längste Pause der Hauptschleife. Im Debug-Bau parst SwiftTerm nur rund 1,4 MB/s
/// (Release: über 200 MB/s, build/m4/bench.sh) – die Zahl hier taugt nur zum Vergleich, nicht als Grenze.
@MainActor
final class ThroughputTests: XCTestCase {
    private func run(logging: Bool, file: URL) throws -> (seconds: Double, longestStall: Double) {
        let window: NSWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled],
                                        backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false   // sonst gibt close() das Fenster ein zweites Mal frei
        defer { window.close() }
        let terminal: TerminalView = TerminalView(frame: window.contentLayoutRect)
        window.contentView = terminal
        window.orderFront(nil)
        let logFolder: URL = file.deletingLastPathComponent().appendingPathComponent("Logs-\(logging)")
        let log: SessionLogWriter? = logging ? try SessionLogWriter(sessionName: "Tempo", folder: logFolder) : nil

        let process: TerminalProcess = TerminalProcess()
        var received: Int = 0
        var ended: Bool = false
        process.onOutput = { bytes in
            received += bytes.count
            log?.write(bytes)
            terminal.feed(byteArray: bytes)
        }
        process.onExit = { _ in ended = true }
        let start: Date = .now
        try process.start(executable: "/bin/cat", arguments: [file.path], environment: [], columns: 120, rows: 40)
        var longestStall: Double = 0
        var last: Date = .now
        while !ended, Date.now.timeIntervalSince(start) < 120 {
            RunLoop.main.run(until: Date.now.addingTimeInterval(0.01))
            longestStall = max(longestStall, Date.now.timeIntervalSince(last))
            last = .now
        }
        log?.close()
        let seconds: Double = Date.now.timeIntervalSince(start)
        XCTAssertTrue(ended, "nach 120 s noch nicht fertig")
        let megabytes: Double = Double(received) / 1_000_000
        print("Durchsatz \(logging ? "mit" : "ohne") Protokoll: \(String(format: "%.1f", megabytes)) MB in "
              + "\(String(format: "%.2f", seconds)) s = \(String(format: "%.1f", megabytes / seconds)) MB/s, "
              + "längste Pause der Hauptschleife \(String(format: "%.0f", longestStall * 1_000)) ms")
        return (seconds, longestStall)
    }

    func testLargeOutputStaysResponsive() throws {
        let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file: URL = folder.appendingPathComponent("ausgabe.txt")
        var payload: Data = Data()
        for number in 1...1_000_000 { payload.append(contentsOf: "Zeile \(number)\n".utf8) }   // rund 13 MB
        try payload.write(to: file)
        let plain: (seconds: Double, longestStall: Double) = try run(logging: false, file: file)
        let logged: (seconds: Double, longestStall: Double) = try run(logging: true, file: file)
        XCTAssertLessThan(logged.seconds, plain.seconds * 1.5 + 2, "das Protokoll bremst deutlich")
        // Hang-Grenze 250 ms (apple-skills:performance); RL 3.7.3 nennt 100 ms als Ziel
        XCTAssertLessThan(max(plain.longestStall, logged.longestStall), 0.25)
    }
}
