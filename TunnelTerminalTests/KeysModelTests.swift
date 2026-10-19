import XCTest
@testable import TunnelTerminal

/// Der Befehl zum Eintragen des öffentlichen Schlüssels auf dem Server (M3): Leonard kopiert ihn und führt ihn selbst
/// aus. Er muss auch mit „'“ im Kommentar und einer Datei ohne Zeilenende am Schluss eine eigene, saubere Zeile ergeben.
/// Läuft hier mit einem eigenen HOME in einem Testordner, nie im echten `~/.ssh` (RL 3.9).
@MainActor
final class KeysModelTests: XCTestCase {
    func testInstallCommandAppendsOwnLine() throws {
        let home: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        let ssh: URL = home.appendingPathComponent(".ssh")
        try FileManager.default.createDirectory(at: ssh, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }
        let keys: URL = ssh.appendingPathComponent("authorized_keys")
        try Data("ssh-ed25519 AAAAvorhanden alt".utf8).write(to: keys)   // ohne Zeilenende am Schluss
        let publicKey: String = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest test's \\n -e key"

        let shell: Process = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", KeysModel.installCommand(for: publicKey)]
        shell.environment = ["HOME": home.path, "PATH": "/usr/bin:/bin"]
        try shell.run()
        shell.waitUntilExit()
        XCTAssertEqual(shell.terminationStatus, 0)

        let lines: [String] = try String(contentsOf: keys, encoding: .utf8).split(separator: "\n").map(String.init)
        XCTAssertEqual(lines, ["ssh-ed25519 AAAAvorhanden alt", publicKey])
        let mode: Int = (try FileManager.default.attributesOfItem(atPath: keys.path)[.posixPermissions] as? Int ?? 0) & 0o777
        XCTAssertEqual(mode, 0o600)
    }

    func testPassphraseWithLineBreakIsRefused() {
        XCTAssertNotNil(KeysModel.passphraseProblem("geh\neim"))
        XCTAssertNotNil(KeysModel.passphraseProblem("geh\reim"))
        XCTAssertNil(KeysModel.passphraseProblem("geh eim"))
        XCTAssertNil(KeysModel.passphraseProblem(""))
    }
}
