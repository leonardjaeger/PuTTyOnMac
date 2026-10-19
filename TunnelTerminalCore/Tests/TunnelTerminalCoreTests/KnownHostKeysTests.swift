import Foundation
import Testing
@testable import TunnelTerminalCore

/// Bekannte Hostschlüssel aus PuTTYs `sshhostkeys` (Format `unix/storage.c`, docs/M3-Recherche.md 3).
/// Die Vektoren stammen aus der Machbarkeit: Wegwerf-Hostschlüssel, von plink 0.85 gespeichert, Fingerabdruck von
/// `ssh-keygen -lf` (unabhängige Quelle). Der Server ist durch einen Platzhalter ersetzt (S14).
@Suite("Bekannte Hostschlüssel")
struct KnownHostKeysTests {
    private static let ed25519: String = "ssh-ed25519@22:server.example 0x57741977920863dda800962bcf07537e6cdb7636caf1132e6948554ea38a73df,0x3da590589456d9724387b8c6b7755bde15eaae0ad34d62b36e10d46d7e5635ab"
    /// x hat nur 63 Ziffern (PuTTY schreibt keine führenden Nullen)
    private static let ed25519Short: String = "ssh-ed25519@2222:192.0.2.7 0xc83b0ffc882e47fa503aa9a1e69e14c3741e83dd1e706530afc3888fdc4255f,0x20e97b332837626662b959266e623d365ce211070a769ab1ac2522e8e4b12ff9"
    private static let ecdsa: String = "ecdsa-sha2-nistp256@22:server.example nistp256,0x1362b65c8f1f99c7bbe282af31fd96be4c346c6d20ab7bcd88f2aa5dda028a6e,0xf9b98e03ebe1ffd1110c1abeab54ee431271338ad23e197b55786e4faa145365"
    private static let rsa: String = "rsa2@2223:server.example 0x10001,0xc81b33f6843e6b58007ca0e7c475320e9bdba156adafd772a6cfed8712461ff6ebcd5fef644da11e66548851a473eaa91c58181b8a19688d510904b769684ffd7ac7a15a90dfad3eb97a9610ab92ed40572d9e4f574875accad1a5373d02013660ef1699efb8ddfd0f43fc985d17c6decd87f66dd3457fe962d5d21c33af2c6f1794fb953cf918b37ab50bb6953a159972638978f63d9c43b670f3eb5008ab7ecf6fc7eec7dcd87eff94cb48359f58e61bd2119e341bb3f5cd08f782edb1b43d099463c5a11d20c1a30357e1f366944487d3a04048fecbd97ab6147cb9678f18028ecbf0aad25ea1cce24ab214c6f71237a3bcf603c85eb76c87ddd0a386dd0d12203516beafeced679f0127ef92272431299f18875d674cac5c5c7f25e936cc72aeb4f7f80f6ba9c01ed3b1fd59c1d11318d38d309d96f7ed28cc181d38f84f6caab29e14d2e0957da5ac93b2623e4b03f1ffa1c90879964f0517ee472142b076891be8569a3f50ee244d969c93859eb5ea6274989f9d1724efe36071b9d369"

    private func keys(_ lines: String...) -> KnownHostKeys {
        KnownHostKeys(contents: Data((lines.joined(separator: "\n") + "\n").utf8))
    }

    @Test("Fingerabdruck wie ssh-keygen (SHA256)", arguments: [
        (ed25519, "SHA256:mWmGD8PIggenkzHnH0aT71MV8nfIagtGp6d2jSAUc8U", "ED25519"),
        (ed25519Short, "SHA256:d8O+V1cv7zO3phubexSY0s8SgnqnQNrfsH1lr54vovU", "ED25519"),
        (ecdsa, "SHA256:xCKWCJP8h9y1dpR3Prv4JopvAZfbxbLx1HpbPMM65WQ", "ECDSA P-256"),
        (rsa, "SHA256:A9EjCxMfFf3o54Ocf1rPWb5RUJ7f+yW6fVJ+g1/dNxE", "RSA 3072")
    ])
    func fingerprints(line: String, fingerprint: String, title: String) throws {
        let entry: KnownHostKey = try #require(keys(line).entries.first)
        #expect(entry.fingerprint == fingerprint)
        #expect(entry.typeTitle == title)
    }

    @Test("Zeile zerlegen: Typ, Port, Server")
    func parsesHeader() throws {
        let entry: KnownHostKey = try #require(keys(Self.rsa).entries.first)
        #expect(entry.keyType == "rsa2")
        #expect(entry.port == 2223)
        #expect(entry.host == "server.example")
        #expect(entry.id == "rsa2@2223:server.example")
    }

    @Test("Einträge zu Server und Port")
    func filtersByServer() {
        let all: KnownHostKeys = keys(Self.ed25519, Self.ed25519Short, Self.ecdsa, Self.rsa)
        #expect(all.entries(host: "server.example", port: 22).map(\.keyType) == ["ssh-ed25519", "ecdsa-sha2-nistp256"])
        #expect(all.entries(host: "SERVER.example", port: 22).isEmpty)   // PuTTY vergleicht genau
        #expect(all.entries(host: "192.0.2.7", port: 2222).count == 1)
    }

    @Test("Entfernen lässt alle anderen Zeilen byte-gleich, auch unlesbare")
    func removeKeepsOthers() {
        let text: String = "kaputt ohne kopf\n\(Self.ed25519)\nssh-ed25519@x:server.example 0x1,0x2\n\(Self.rsa)\n"
        var all: KnownHostKeys = KnownHostKeys(contents: Data(text.utf8))
        #expect(all.entries.count == 2)
        all.remove(["ssh-ed25519@22:server.example"])
        #expect(String(decoding: all.contents, as: UTF8.self)
                == "kaputt ohne kopf\nssh-ed25519@x:server.example 0x1,0x2\n\(Self.rsa)\n")
    }

    @Test("Unlesbarer Schlüssel: Eintrag bleibt sichtbar und entfernbar, ohne Fingerabdruck", arguments: [
        "ssh-ed25519@22:server.example 0xzz,0x1",
        "ssh-ed25519@22:server.example 0x1",
        "ecdsa-sha2-nistp256@22:server.example nistp999,0x1,0x2",
        "rsa2@22:server.example 0x,0x5",
        "ssh-ed448@22:server.example 0x1,0x2",
        "dss@22:server.example 0x1,0x2,0x3,0x4",
        "ssh-ed25519@22:server.example 0x" + String(repeating: "f", count: 5_000) + ",0x1"
    ])
    func unreadableValue(_ line: String) throws {
        let entry: KnownHostKey = try #require(keys(line).entries.first)
        #expect(entry.fingerprint == nil)
    }

    @Test("Leere oder fehlende Datei")
    func empty() {
        #expect(KnownHostKeys(contents: Data()).entries.isEmpty)
        #expect(KnownHostKeys(contents: Data()).contents.isEmpty)
    }
}
