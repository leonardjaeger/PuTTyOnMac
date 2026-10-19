import XCTest
@testable import TunnelTerminal

/// Prozessstart am eigenen Pseudo-Terminal (Plan S8, M0 Weg B).
@MainActor
final class TerminalProcessTests: XCTestCase {
    private struct Run {
        let process: TerminalProcess
        let ended: XCTestExpectation
        var output: () -> String
        var status: () -> Int32
    }

    private func launch(_ executable: String, _ arguments: [String] = [], environment: [String] = ["PATH=/usr/bin:/bin"],
                        columns: Int = 80, rows: Int = 24, secret: Data? = nil) throws -> Run {
        let process: TerminalProcess = TerminalProcess()
        let ended: XCTestExpectation = expectation(description: "Prozessende")
        var bytes: [UInt8] = []
        var status: Int32 = -1
        process.onOutput = { bytes.append(contentsOf: $0) }
        process.onExit = { status = $0; ended.fulfill() }
        try process.start(executable: executable, arguments: arguments, environment: environment,
                          columns: columns, rows: rows, secret: secret)
        return Run(process: process, ended: ended,
                   output: { String(decoding: bytes, as: UTF8.self) }, status: { status })
    }

    private func finish(_ run: Run) -> (String, Int32) {
        wait(for: [run.ended], timeout: 10)
        return (run.output(), run.status())
    }

    func testChildInheritsOnlyTerminal() throws {
        // Absichtlich ein vererbbarer Deskriptor in der App: das Kind darf ihn trotzdem nicht sehen
        let leak: Int32 = open("/dev/null", O_RDONLY)
        XCTAssertGreaterThanOrEqual(leak, 3)
        defer { close(leak) }
        let probe: String = "for n in 0 1 2 \(leak); do if : <&$n; then echo \"offen $n\"; else echo \"zu $n\"; fi; done 2>/dev/null"
        let (output, status) = finish(try launch("/bin/sh", ["-c", probe]))
        XCTAssertEqual(status, 0)
        XCTAssertEqual(output.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) },
                       ["offen 0", "offen 1", "offen 2", "zu \(leak)"])
    }

    func testStartSizeIsVisibleToChild() throws {
        let (output, _) = finish(try launch("/bin/stty", ["size"], columns: 100, rows: 30))
        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines), "30 100")
    }

    func testResizeReachesChild() throws {
        let run: Run = try launch("/bin/sh", ["-c", "trap 'stty size; exit 0' WINCH; sleep 5 & wait"])
        RunLoop.current.run(until: Date.now.addingTimeInterval(0.5))   // Shell hat den trap gesetzt
        run.process.resize(columns: 120, rows: 40)
        let (output, _) = finish(run)
        XCTAssertTrue(output.contains("40 120"), output)
    }

    func testSendNeverBlocksAndDeliversLater() throws {
        // Das Programm liest erst nach einer Sekunde: vorher ist das Terminal voll, `send` muss trotzdem sofort zurück
        let script: String = "stty raw -echo; sleep 1; head -c 1000000 | wc -c; echo fertig"
        let run: Run = try launch("/bin/sh", ["-c", script])
        RunLoop.current.run(until: Date.now.addingTimeInterval(0.2))   // stty ist durch
        let begin: Date = .now
        run.process.send(ArraySlice(repeating: UInt8(ascii: "a"), count: 1_000_000))
        XCTAssertLessThan(Date.now.timeIntervalSince(begin), 0.5)
        let (output, status) = finish(run)
        XCTAssertEqual(status, 0)
        XCTAssertTrue(output.contains("1000000"), output)
        XCTAssertTrue(output.contains("fertig"), output)
    }

    func testFilesOfChildArePrivate() throws {
        let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file: URL = folder.appendingPathComponent("neu")
        _ = finish(try launch("/usr/bin/touch", [file.path]))
        let attributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual((attributes[.posixPermissions] as? Int ?? 0) & 0o777, 0o600)
    }

    func testEnvironmentIsExactlyTheGivenList() throws {
        let (output, _) = finish(try launch("/usr/bin/env", environment: ["A=1", "B=zwei"]))
        XCTAssertEqual(output.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) },
                       ["A=1", "B=zwei"])
    }

    func testHangUpEndsChild() throws {
        let run: Run = try launch("/bin/sleep", ["30"])
        XCTAssertTrue(run.process.isRunning)
        run.process.hangUp()
        let (_, status) = finish(run)
        XCTAssertEqual(status & 0x7F, SIGHUP)
        XCTAssertFalse(run.process.isRunning)
    }

    func testStartFailureIsReported() {
        let process: TerminalProcess = TerminalProcess()
        XCTAssertThrowsError(try process.start(executable: "/gibt/es/nicht", arguments: [], environment: [],
                                               columns: 80, rows: 24))
        XCTAssertFalse(process.isRunning)
    }

    func testStatusTexts() {
        XCTAssertEqual(TerminalProcess.describe(status: 0), "Verbindung beendet.")
        XCTAssertEqual(TerminalProcess.describe(status: 1 << 8), "Verbindung beendet (Exit-Code 1).")
        XCTAssertEqual(TerminalProcess.describe(status: SIGHUP), "Verbindung beendet (Signal 1).")
    }

    /// Passwort aus dem Schlüsselbund (M3, S1): nur über eine Pipe auf fd 3, eine Zeile, nicht in der Prozessliste.
    func testSecretArrivesOnlyOnDescriptorThree() throws {
        let leak: Int32 = open("/dev/null", O_RDONLY)
        defer { close(leak) }
        let probe: String = "for n in 0 1 2 3 \(leak); do if : <&$n; then echo \"offen $n\"; else echo \"zu $n\"; fi; done 2>/dev/null; "
            + "IFS= read -r p <&3; echo \"[$p]\"; if IFS= read -r rest <&3; then echo mehr; else echo ende; fi; ps -o args= -p $$"
        let (output, status) = finish(try launch("/bin/sh", ["-c", probe], secret: Data("geh eim ä".utf8)))
        XCTAssertEqual(status, 0)
        let lines: [String] = output.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertEqual(Array(lines.prefix(7)), ["offen 0", "offen 1", "offen 2", "offen 3", "zu \(leak)", "[geh eim ä]", "ende"])
        XCTAssertFalse(lines.dropFirst(7).joined().contains("geh eim"), output)
    }

    func testWithoutSecretDescriptorThreeStaysClosed() throws {
        let (output, _) = finish(try launch("/bin/sh", ["-c", "if : <&3; then echo offen; else echo zu; fi 2>/dev/null"]))
        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines), "zu")
    }

    func testOversizedSecretIsRefused() {
        let process: TerminalProcess = TerminalProcess()
        XCTAssertThrowsError(try process.start(executable: "/bin/cat", arguments: [], environment: [], columns: 80, rows: 24,
                                               secret: Data(repeating: 0x61, count: TerminalProcess.secretLimit + 1)))
        XCTAssertFalse(process.isRunning)
    }
}
