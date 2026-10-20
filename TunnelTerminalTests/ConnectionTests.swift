import Security
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

    /// Gespeicherte Sitzung: plink lädt sie direkt (`-load <Name>`), die Datei bleibt nach dem Ende erhalten.
    func testSavedSessionConnectsAndStays() throws {
        let probe: (descriptor: Int32, port: Int) = try localSocket(listening: false)
        close(probe.descriptor)
        let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: folder)
        var file: SessionFile = SessionFile()
        file.setConnectionProtocol(.raw)
        try file.setHostName("127.0.0.1")
        try file.setPortNumber(probe.port)
        try directory.write(file, sessionName: "Test/Mein Raw")

        let connection: Connection = try Connection(savedSession: "Test/Mein Raw", puttyDirectory: { directory })
        XCTAssertEqual(connection.displayName, "Test/Mein Raw")
        XCTAssertNil(connection.quickAddress)
        let ended: XCTestExpectation = expectation(description: "Verbindungsende")
        var bytes: [UInt8] = []
        connection.onOutput = { bytes.append(contentsOf: $0) }
        connection.onEnd = { _ in ended.fulfill() }
        try connection.start(columns: 80, rows: 24)
        wait(for: [ended], timeout: 15)
        XCTAssertTrue(String(decoding: bytes, as: UTF8.self).contains("refused"))
        XCTAssertEqual(directory.sessionNames(), ["Test/Mein Raw"])
        XCTAssertEqual(try directory.read(sessionNamed: "Test/Mein Raw"), file)
    }

    /// Inspektor: Einstellungen der Schnellsitzung bzw. der gespeicherten Sitzung (ohne Zwischendatei).
    func testSettingsForInspector() throws {
        let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: folder)
        var file: SessionFile = SessionFile()
        try file.setHostName("server.example")
        try directory.write(file, sessionName: "Gespeichert")
        XCTAssertEqual(try Connection(savedSession: "Gespeichert", puttyDirectory: { directory }).settings(), file)
        let quick: Connection = try Connection(endpoint: try Endpoint(parsing: "test@192.0.2.1"), connectionProtocol: .ssh,
                                               puttyDirectory: { directory })
        XCTAssertEqual(quick.settings()?.hostName, "192.0.2.1")
        XCTAssertEqual(directory.sessionNames(), ["Gespeichert"])   // nur gelesen, nichts geschrieben
        XCTAssertNil(try Connection(savedSession: "Fehlt", puttyDirectory: { directory }).settings())
    }

    func testSavedSessionNameIsChecked() {
        XCTAssertThrowsError(try Connection(savedSession: "-proxycmd x"))
        XCTAssertThrowsError(try Connection(savedSession: AppIdentity.quickSessionPrefix + "x"))
    }

    /// Rückfrage auch für Gefahren aus einer SSH-Proxy-Sitzung; nicht lesbare Sitzung: kein Verbinden (S4).
    func testWarningsFollowProxySessionsAndFailClosed() throws {
        let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: folder)
        var proxy: SessionFile = SessionFile()
        try proxy.setValue("5", forKey: "ProxyMethod")
        try proxy.setValue("nc %host %port", forKey: "ProxyTelnetCommand")
        try directory.write(proxy, sessionName: "Sprung")
        var main: SessionFile = SessionFile()
        try main.setHostName("server.example")
        try main.setValue("6", forKey: "ProxyMethod")
        try main.setValue("Sprung", forKey: "ProxyHost")
        try directory.write(main, sessionName: "Ziel")

        let connection: Connection = try Connection(savedSession: "Ziel", puttyDirectory: { directory })
        XCTAssertEqual(try connection.warningsRequiringConfirmation(), [.viaProxy("Sprung", .localProxyCommand("nc  22"))])

        try Data(count: PuTTYDirectory.maximumSessionSize + 1)
            .write(to: folder.appendingPathComponent("sessions").appendingPathComponent("Sprung"))
        XCTAssertThrowsError(try connection.warningsRequiringConfirmation())
        XCTAssertTrue(try Connection(endpoint: try Endpoint(parsing: "server.example"), connectionProtocol: .ssh)
            .warningsRequiringConfirmation().isEmpty)
    }

    // MARK: - Gespeichertes Passwort (M3, S1)

    /// SSH-Sitzung auf einen abweisenden Port und ein Schlüsselbund nur für diesen Test.
    private func passwordSession(storedFor target: String?) throws -> (Connection, PasswordStore) {
        let probe: (descriptor: Int32, port: Int) = try localSocket(listening: false)
        close(probe.descriptor)
        let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let directory: PuTTYDirectory = try PuTTYDirectory(url: folder)
        var file: SessionFile = SessionFile()
        try file.setHostName("127.0.0.1")
        try file.setPortNumber(probe.port)
        try file.setUserName("test")
        try directory.write(file, sessionName: "Mit Passwort")
        let store: PasswordStore = PasswordStore(service: "\(AppIdentity.logSubsystem).tests.\(UUID().uuidString)")
        addTeardownBlock { SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: store.service] as CFDictionary) }
        if let target { try store.save("geheim-1234", session: "Mit Passwort", target: target) }
        return (try Connection(savedSession: "Mit Passwort", puttyDirectory: { directory }, passwords: store), store)
    }

    private func run(_ connection: Connection) -> String {
        let ended: XCTestExpectation = expectation(description: "Verbindungsende")
        var bytes: [UInt8] = []
        connection.onOutput = { bytes.append(contentsOf: $0) }
        connection.onEnd = { _ in ended.fulfill() }
        XCTAssertNoThrow(try connection.start(columns: 80, rows: 24))
        wait(for: [ended], timeout: 15)
        return String(decoding: bytes, as: UTF8.self)
    }

    /// plink nimmt `-pwfile /dev/fd/3` an (sonst Fehlermeldung zur Option) und läuft bis zur Verbindung.
    func testStoredPasswordGoesToPlinkThroughPipe() throws {
        let (connection, store) = try passwordSession(storedFor: nil)
        let target: String = try XCTUnwrap(connection.settings()?.passwordTarget)
        try store.save("geheim-1234", session: "Mit Passwort", target: target)
        XCTAssertTrue(connection.hasStoredPassword)
        let output: String = run(connection)
        XCTAssertTrue(connection.usesStoredPassword)
        XCTAssertTrue(output.contains("refused"), output)
        XCTAssertFalse(output.contains("geheim-1234"))
        XCTAssertFalse(try connection.again(withStoredPassword: false).hasStoredPassword)
        XCTAssertTrue(try connection.again().hasStoredPassword)
    }

    func testPasswordForOtherTargetIsNotUsed() throws {
        let (connection, _) = try passwordSession(storedFor: "test@server.example:22")
        let output: String = run(connection)
        XCTAssertFalse(connection.usesStoredPassword)
        XCTAssertTrue(output.contains("Gespeichertes Passwort nicht verwendet"), output)
    }

    /// plinks Meldung kann über zwei Lese-Blöcke verteilt ankommen (M3).
    func testRejectedPasswordIsFoundAcrossBlocks() {
        let message: [UInt8] = Array("\r\nConfigured password was not accepted\r\n".utf8)
        for split in 1..<message.count {
            var watch: RejectedPasswordWatch = RejectedPasswordWatch()
            watch.scan(ArraySlice(Array("Vorspann ".utf8)))
            watch.scan(message[..<split])
            watch.scan(message[split...])
            XCTAssertTrue(watch.found, "Teilung bei \(split)")
        }
        var other: RejectedPasswordWatch = RejectedPasswordWatch()
        other.scan(ArraySlice(Array("Configured password was not".utf8)))
        other.scan(ArraySlice(Array(" quite right".utf8)))
        XCTAssertFalse(other.found)
    }
}
