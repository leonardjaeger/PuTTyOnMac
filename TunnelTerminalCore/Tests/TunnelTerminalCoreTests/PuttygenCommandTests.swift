import Testing
@testable import TunnelTerminalCore

/// Aufrufe von puttygen für das Schlüssel-Fenster (M3). Passphrasen gehen nie als Argument, sondern über Pipes
/// (`/dev/fd/3`), wie bei plink (S1). puttygen-Verhalten: docs/M3-Recherche.md 2.
@Suite("puttygen-Aufruf")
struct PuttygenCommandTests {
    @Test("Neuen Schlüssel erzeugen: Typ, Kommentar, Ziel; Passphrase über fd 3", arguments: [
        (KeyKind.ed25519, ["-t", "ed25519"]),
        (KeyKind.ecdsa, ["-t", "ecdsa", "-b", "256"]),
        (KeyKind.rsa, ["-t", "rsa", "-b", "4096"])
    ])
    func generate(kind: KeyKind, typeArguments: [String]) throws {
        let command: PuttygenCommand = try .generate(kind, comment: "test@server.example", output: "/tmp/neu.ppk")
        #expect(command.arguments == typeArguments + ["-C", "test@server.example", "-q", "-o", "/tmp/neu.ppk",
                                                      "--new-passphrase", "/dev/fd/3"])
    }

    @Test("Ed25519 ist der Standard")
    func defaultKind() {
        #expect(KeyKind.standard == .ed25519)
    }

    @Test("Öffentlichen Schlüssel und Fingerabdruck lesen; Passphrase nur, wenn nötig")
    func readPublic() throws {
        #expect(try PuttygenCommand.publicKey(of: "/tmp/a.ppk", withPassphrase: false).arguments == ["/tmp/a.ppk", "-L"])
        #expect(try PuttygenCommand.publicKey(of: "/tmp/a", withPassphrase: true).arguments
                == ["/tmp/a", "-L", "--old-passphrase", "/dev/fd/3"])
        #expect(try PuttygenCommand.fingerprint(of: "/tmp/a.ppk", withPassphrase: false).arguments
                == ["/tmp/a.ppk", "-l", "-E", "sha256"])
    }

    @Test("Umwandeln .ppk ↔ OpenSSH: Passphrase bleibt erhalten (alte über fd 3)")
    func convert() throws {
        #expect(try PuttygenCommand.convert("/tmp/a.ppk", to: .openSSH, output: "/tmp/a").arguments
                == ["/tmp/a.ppk", "-O", "private-openssh", "-o", "/tmp/a", "--old-passphrase", "/dev/fd/3"])
        #expect(try PuttygenCommand.convert("/tmp/a", to: .putty, output: "/tmp/a.ppk").arguments
                == ["/tmp/a", "-O", "private", "-o", "/tmp/a.ppk", "--old-passphrase", "/dev/fd/3"])
    }

    @Test("Pfade nur absolut und ohne Steuerzeichen (sonst läse puttygen sie als Option)", arguments: [
        "-O", "relativ.ppk", "", "/tmp/zeile\nzwei", "~/a.ppk"
    ])
    func rejectsPaths(_ path: String) {
        #expect(throws: InputError.self) { try PuttygenCommand.publicKey(of: path, withPassphrase: false) }
        #expect(throws: InputError.self) { try PuttygenCommand.generate(.ed25519, comment: "x", output: path) }
        #expect(throws: InputError.self) { try PuttygenCommand.convert("/tmp/a", to: .putty, output: path) }
    }

    @Test("Kommentar: Leerzeichen ja, Steuerzeichen und führendes „-“ nein")
    func comment() throws {
        _ = try PuttygenCommand.generate(.ed25519, comment: "Mein Mac 2026", output: "/tmp/a.ppk")
        _ = try PuttygenCommand.generate(.ed25519, comment: "", output: "/tmp/a.ppk")
        #expect(throws: InputError.leadingDash(.comment)) { try PuttygenCommand.generate(.ed25519, comment: "-x", output: "/tmp/a") }
        #expect(throws: InputError.controlCharacter(.comment)) {
            try PuttygenCommand.generate(.ed25519, comment: "a\u{1B}[2J", output: "/tmp/a")
        }
    }

    @Test("Ausgaben lesen: Fingerabdruck und öffentlicher Schlüssel")
    func parsesOutput() {
        #expect(PuttygenCommand.fingerprint(fromOutput: "ssh-ed25519 255 SHA256:9cFhau7zTlYQ68b5yfzOEjoKkfBcq/6ESvkRVdbO2wc test-schluessel\n")
                == "SHA256:9cFhau7zTlYQ68b5yfzOEjoKkfBcq/6ESvkRVdbO2wc")
        #expect(PuttygenCommand.fingerprint(fromOutput: "irgendwas\n") == nil)
        #expect(PuttygenCommand.publicKey(fromOutput: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC test\n")
                == "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC test")
        #expect(PuttygenCommand.publicKey(fromOutput: "puttygen: error\n") == nil)
        #expect(PuttygenCommand.publicKey(fromOutput: "ssh-ed25519 AAAA\u{1B}[31m x\n") == nil)
    }

    @Test("Fehlertexte von puttygen in verständliche Meldungen")
    func errors() {
        #expect(PuttygenCommand.problem(fromErrorOutput: "puttygen: error loading `/tmp/a.ppk': wrong passphrase\n") == .wrongPassphrase)
        #expect(PuttygenCommand.problem(fromErrorOutput: "Enter passphrase to load key: \n") == .passphraseNeeded)
        #expect(PuttygenCommand.problem(fromErrorOutput: "puttygen: error loading `/tmp/a': not a private key\n")
                == .other("Fehler beim Laden: not a private key"))
    }
}
