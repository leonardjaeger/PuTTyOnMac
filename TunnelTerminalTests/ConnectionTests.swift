import TunnelTerminalCore
import XCTest
@testable import TunnelTerminal

/// Ende-zu-Ende mit dem eingebauten plink, ohne Server: Raw auf lokale Ports.
/// Jeder Test nutzt einen eigenen PuTTY-Ordner, nie den der App (RL 3.9: kein Zustand bleibt zurück).
@MainActor
final class ConnectionTests: XCTestCase {
    private func connection(toPort port: Int) throws -> (Connection, PuTTYDirectory) {
        let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: folder)
        let connection: Connection = try Connection(endpoint: try Endpoint(parsing: "127.0.0.1:\(port)"),
                                                    connectionProtocol: .raw, puttyDirectory: { directory })
        return (connection, directory)
    }

    func testBundledPlinkIsOurBuild() throws {
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: AppIdentity.plinkPath))
        let process: TerminalProcess = TerminalProcess()
        let ended: XCTestExpectation = expectation(description: "plink -V")
        var bytes: [UInt8] = []
        process.onOutput = { bytes.append(contentsOf: $0) }
        process.onExit = { _ in ended.fulfill() }
        try process.start(executable: AppIdentity.plinkPath, arguments: ["-V"], environment: [], columns: 80, rows: 24)
        wait(for: [ended], timeout: 10)
        XCTAssertTrue(String(decoding: bytes, as: UTF8.self).contains("Release 0.85"))
    }

    /// Lokaler Socket auf einem freien Port; ohne `listen` weist der Port Verbindungen ab, sobald er zu ist.
    private func localSocket(listening: Bool) throws -> (descriptor: Int32, port: Int) {
        let socketDescriptor: Int32 = socket(AF_INET, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(socketDescriptor, 0)
        var address: sockaddr_in = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var length: socklen_t = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound: Int32 = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(socketDescriptor, $0, length) }
        }
        XCTAssertEqual(bound, 0)
        if listening { XCTAssertEqual(listen(socketDescriptor, 1), 0) }
        _ = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(socketDescriptor, $0, &length) }
        }
        return (socketDescriptor, Int(UInt16(bigEndian: address.sin_port)))
    }

    func testRefusedConnectionEndsAndRemovesSession() throws {
        let probe: (descriptor: Int32, port: Int) = try localSocket(listening: false)
        close(probe.descriptor)   // jetzt lauscht dort sicher niemand
        let (connection, directory) = try connection(toPort: probe.port)
        let ended: XCTestExpectation = expectation(description: "Verbindungsende")
        var bytes: [UInt8] = []
        var message: String = ""
        connection.onOutput = { bytes.append(contentsOf: $0) }
        connection.onEnd = { message = $0; ended.fulfill() }
        try connection.start(columns: 80, rows: 24)
        XCTAssertEqual(directory.sessionFileNames().count, 1)
        wait(for: [ended], timeout: 15)

        let output: String = String(decoding: bytes, as: UTF8.self)
        // Der gewählte Port statt 22: PortNumber aus der Sitzungsdatei wirkt (docs/M1-Recherche.md 2.1).
        // Zugleich Regressionstest für Scripts/putty-patches/0001 (ohne Patch hängt plink hier mit voller CPU).
        XCTAssertTrue(output.contains("refused"), output)
        XCTAssertEqual(message, "Verbindung beendet (Exit-Code 1).")
        XCTAssertEqual(directory.sessionFileNames(), [])
    }

    func testHangUpReportsDisconnect() throws {
        let server: (descriptor: Int32, port: Int) = try localSocket(listening: true)
        defer { close(server.descriptor) }
        let (connection, _) = try connection(toPort: server.port)
        let ended: XCTestExpectation = expectation(description: "Verbindungsende")
        var message: String = ""
        connection.onEnd = { message = $0; ended.fulfill() }
        try connection.start(columns: 80, rows: 24)
        RunLoop.current.run(until: Date.now.addingTimeInterval(0.5))
        XCTAssertTrue(connection.isRunning)
        connection.hangUp()
        wait(for: [ended], timeout: 10)
        XCTAssertEqual(message, "Verbindung getrennt.")
    }
}
