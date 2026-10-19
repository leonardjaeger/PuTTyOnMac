import TunnelTerminalCore
import XCTest
@testable import TunnelTerminal

/// Das eingebaute puttygen über `HelperProcess` (M3): Passphrasen nur über Pipes, private Schlüssel mit 0600,
/// verständliche Fehler. Nur in einem eigenen Ordner (RL 3.9), Kommentare mit Platzhaltern (S14).
@MainActor
final class HelperProcessTests: XCTestCase {
    private var folder: URL!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let created: URL = folder
        addTeardownBlock { try? FileManager.default.removeItem(at: created) }
    }

    private func puttygen(_ command: PuttygenCommand, _ secrets: [Data] = []) async throws -> HelperProcess.Result {
        try await HelperProcess.run(HelperProcess.puttygenPath, command.arguments, secrets: secrets)
    }

    func testGenerateReadAndConvertWithPassphrase() async throws {
        let key: URL = folder.appendingPathComponent("test.ppk")
        let created: HelperProcess.Result = try await puttygen(try .generate(.ed25519, comment: "test@server.example",
                                                                               output: key.path), [Data("geh eim".utf8)])
        XCTAssertTrue(created.succeeded, created.output)
        let mode: Int = (try FileManager.default.attributesOfItem(atPath: key.path)[.posixPermissions] as? Int ?? 0) & 0o777
        XCTAssertEqual(mode, 0o600)
        XCTAssertTrue(try String(contentsOf: key, encoding: .utf8).contains("Encryption: aes256-cbc"))

        // Der öffentliche Teil einer .ppk braucht keine Passphrase
        let publicKey: HelperProcess.Result = try await puttygen(try .publicKey(of: key.path, withPassphrase: false))
        XCTAssertEqual(PuttygenCommand.publicKey(fromOutput: publicKey.output)?.hasSuffix(" test@server.example"), true)
        let fingerprint: HelperProcess.Result = try await puttygen(try .fingerprint(of: key.path, withPassphrase: false))
        XCTAssertEqual(PuttygenCommand.fingerprint(fromOutput: fingerprint.output)?.hasPrefix("SHA256:"), true)

        let openSSH: URL = folder.appendingPathComponent("test_openssh")
        let wrong: HelperProcess.Result = try await puttygen(try .convert(key.path, to: .openSSH, output: openSSH.path),
                                                             [Data("falsch".utf8)])
        XCTAssertFalse(wrong.succeeded)
        XCTAssertEqual(PuttygenCommand.problem(fromErrorOutput: wrong.output), .wrongPassphrase)
        let converted: HelperProcess.Result = try await puttygen(try .convert(key.path, to: .openSSH, output: openSSH.path),
                                                                 [Data("geh eim".utf8)])
        XCTAssertTrue(converted.succeeded, converted.output)
        XCTAssertTrue(try String(contentsOf: openSSH, encoding: .utf8).hasPrefix("-----BEGIN OPENSSH PRIVATE KEY-----"))

        // Verschlüsselte OpenSSH-Datei: ohne Passphrase fragt puttygen nicht am Terminal vorbei, sondern bricht ab
        let locked: HelperProcess.Result = try await puttygen(try .publicKey(of: openSSH.path, withPassphrase: false))
        XCTAssertEqual(PuttygenCommand.problem(fromErrorOutput: locked.output), .passphraseNeeded)
        let unlocked: HelperProcess.Result = try await puttygen(try .publicKey(of: openSSH.path, withPassphrase: true),
                                                                [Data("geh eim".utf8)])
        XCTAssertEqual(PuttygenCommand.publicKey(fromOutput: unlocked.output), PuttygenCommand.publicKey(fromOutput: publicKey.output))
    }

    func testPassphraseIsNotInProcessArguments() async throws {
        // Ein kleines Programm statt puttygen zeigt Argumente und fd 3 (wie die Passwort-Pipe für plink)
        let result: HelperProcess.Result = try await HelperProcess.run("/bin/sh", ["-c", "IFS= read -r p <&3; echo \"[$p]\"; ps -o args= -p $$"],
                                                                       secrets: [Data("passphrase-5678".utf8)])
        let lines: [String] = result.output.split(whereSeparator: \.isNewline).map(String.init)
        XCTAssertEqual(lines.first, "[passphrase-5678]")
        XCTAssertFalse(lines.dropFirst().joined().contains("passphrase-5678"))
    }

    /// umask gilt prozessweit: Gleichzeitige Starts (Hilfsprogramme im Hintergrund) dürfen die alte Maske nicht
    /// vertauschen – sonst behielte die App 077 oder ein Kind bekäme die lockere Maske der App.
    func testConcurrentStartsRestoreUmask() async throws {
        let before: mode_t = umask(0o022)
        umask(before)
        try await withThrowingTaskGroup(of: Bool.self) { group in
            for _ in 0..<40 { group.addTask { try await HelperProcess.run("/usr/bin/true", []).succeeded } }
            for try await succeeded in group { XCTAssertTrue(succeeded) }
        }
        let after: mode_t = umask(0o022)
        umask(after)
        XCTAssertEqual(after, before)
    }
}
