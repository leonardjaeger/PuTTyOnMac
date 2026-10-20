import Darwin
import TunnelTerminalCore
import XCTest
@testable import TunnelTerminal

/// M5 Ende-zu-Ende mit dem eingebauten plink: belegter lokaler Port einer Weiterleitung, serielle Verbindung an einem
/// PTY-Paar (Regressionstest für Scripts/putty-patches/0002) und der Menübefehl „Tunnel bearbeiten …“.
@MainActor
final class TunnelSerialTests: XCTestCase {
    private func directory() throws -> PuTTYDirectory {
        let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return try PuTTYDirectory(url: folder)
    }

    func testPortCheckFindsListeningPort() throws {
        let server: (descriptor: Int32, port: Int) = try localSocket(listening: true)
        XCTAssertTrue(PortCheck.isInUse(server.port))
        close(server.descriptor)
        XCTAssertFalse(PortCheck.isInUse(server.port))
        XCTAssertFalse(PortCheck.isInUse(0))
    }

    /// plink meldet einen belegten Port nur mit `-v` – die App sagt es vor dem Start im Terminal und im Inspektor.
    func testBusyForwardingPortIsReported() throws {
        let busy: (descriptor: Int32, port: Int) = try localSocket(listening: true)
        defer { close(busy.descriptor) }
        let refused: (descriptor: Int32, port: Int) = try localSocket(listening: false)
        close(refused.descriptor)
        let folder: PuTTYDirectory = try directory()
        var file: SessionFile = SessionFile()
        try file.setHostName("127.0.0.1")
        try file.setPortNumber(refused.port)
        try file.setPortForwardings([try PortForwarding(kind: .local, port: busy.port, targetHost: "127.0.0.1", targetPort: 80)])
        try folder.write(file, sessionName: "Tunnel")

        let connection: Connection = try Connection(savedSession: "Tunnel", puttyDirectory: { folder }, passwords: nil)
        let ended: XCTestExpectation = expectation(description: "Verbindungsende")
        var bytes: [UInt8] = []
        connection.onOutput = { bytes.append(contentsOf: $0) }
        connection.onEnd = { _ in ended.fulfill() }
        try connection.start(columns: 80, rows: 24)
        XCTAssertEqual(connection.busyLocalPorts, [busy.port])
        wait(for: [ended], timeout: 15)
        XCTAssertTrue(String(decoding: bytes, as: UTF8.self).contains("Lokaler Port \(busy.port) ist schon belegt"))
    }

    /// Seriell: Zeichen gehen sofort und ohne lokales Echo ans Gerät, Ctrl-C und Return (CR) kommen an (M5, Patch 0002).
    func testSerialPassesKeystrokesThrough() throws {
        var device: Int32 = -1
        var line: Int32 = -1
        XCTAssertEqual(openpty(&device, &line, nil, nil, nil), 0)
        defer { close(device); close(line) }
        _ = fcntl(device, F_SETFL, fcntl(device, F_GETFL) | O_NONBLOCK)
        let folder: PuTTYDirectory = try directory()
        var file: SessionFile = SessionFile()
        file.setConnectionProtocol(.serial)
        try file.setSerialLine(String(cString: ttyname(line)))
        try file.setSerialSpeed(115_200)
        file.setSerialFlowControl(.none)
        try folder.write(file, sessionName: "Seriell")

        let connection: Connection = try Connection(savedSession: "Seriell", puttyDirectory: { folder }, passwords: nil)
        let ended: XCTestExpectation = expectation(description: "Verbindungsende")
        var bytes: [UInt8] = []
        connection.onOutput = { bytes.append(contentsOf: $0) }
        connection.onEnd = { _ in ended.fulfill() }
        try connection.start(columns: 80, rows: 24)
        _ = received(on: device, within: 1)
        connection.send(ArraySlice(Array("abc".utf8)))
        XCTAssertEqual(received(on: device, within: 1), Array("abc".utf8), "ohne Return sofort beim Gerät")
        connection.send([0x03, 0x0D])
        XCTAssertEqual(received(on: device, within: 1), [0x03, 0x0D], "Ctrl-C und CR unverändert")
        _ = write(device, "GERAET\r\n", 8)
        RunLoop.main.run(until: Date.now.addingTimeInterval(1))
        let shown: String = String(decoding: bytes, as: UTF8.self)
        XCTAssertTrue(shown.contains("GERAET"), shown)
        XCTAssertFalse(shown.contains("abc"), "kein lokales Echo: \(shown)")
        connection.hangUp()
        wait(for: [ended], timeout: 10)
    }

    func testMenuHasEditTunnels() {
        let menu: NSMenu = MainMenu.build()
        let items: [NSMenuItem] = menu.items.compactMap(\.submenu).flatMap(\.items)
        XCTAssertTrue(items.contains { $0.action == #selector(ConnectionWindowController.editTunnels(_:)) })
    }
}

/// Telnet zu einem Testdienst: Nach der Verhandlung (Server echot, SGA) gehen Zeichen sofort ohne lokales Echo raus.
extension TunnelSerialTests {
    func testTelnetSwitchesToCharacterMode() throws {
        let server: (descriptor: Int32, port: Int) = try localSocket(listening: true)
        defer { close(server.descriptor) }
        let folder: PuTTYDirectory = try directory()
        let connection: Connection = try Connection(endpoint: try Endpoint(parsing: "127.0.0.1:\(server.port)"),
                                                    connectionProtocol: .telnet, puttyDirectory: { folder })
        let ended: XCTestExpectation = expectation(description: "Verbindungsende")
        var bytes: [UInt8] = []
        connection.onOutput = { bytes.append(contentsOf: $0) }
        connection.onEnd = { _ in ended.fulfill() }
        try connection.start(columns: 80, rows: 24)
        let client: Int32 = try accept(on: server.descriptor)
        defer { close(client) }
        _ = write(client, [UInt8]([255, 251, 1, 255, 251, 3]), 6)   // IAC WILL ECHO, IAC WILL SGA
        _ = received(on: client, within: 1)
        connection.send(ArraySlice(Array("ab".utf8)))
        XCTAssertEqual(received(on: client, within: 1), Array("ab".utf8))
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("ab"), "kein lokales Echo")
        connection.hangUp()
        wait(for: [ended], timeout: 10)
    }
}

/// Seriell ohne Gerät: eigene Meldung statt plinks Fehlertext, plink startet gar nicht.
extension TunnelSerialTests {
    func testSerialWithoutDeviceDoesNotStart() throws {
        let folder: PuTTYDirectory = try directory()
        var file: SessionFile = SessionFile()
        file.setConnectionProtocol(.serial)
        try folder.write(file, sessionName: "Ohne Gerät")
        let connection: Connection = try Connection(savedSession: "Ohne Gerät", puttyDirectory: { folder }, passwords: nil)
        XCTAssertThrowsError(try connection.start(columns: 80, rows: 24)) { error in
            XCTAssertEqual((error as? TerminalProcess.Failure)?.message, "Kein serielles Gerät gewählt – im Sitzungs-Editor eines wählen.")
        }
        XCTAssertFalse(connection.isRunning)
    }
}
