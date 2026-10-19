import Foundation
import Testing
@testable import TunnelTerminalCore

/// Wofür ein gespeichertes Passwort gilt (M3, S1): Es ist an Benutzer, Server und Port der Sitzung gebunden und wird
/// nur ohne Proxy verwendet – sonst ginge es nach einer Änderung (Import, Bearbeiten) an einen anderen Rechner.
@Suite("Passwort-Bindung")
struct PasswordTargetTests {
    private func session(_ text: String) throws -> SessionFile {
        try SessionFile(contents: Data(text.utf8))
    }

    @Test("SSH mit Benutzer und Server: benutzer@server:port")
    func target() throws {
        #expect(try session("HostName=server.example\nUserName=test\nProtocol=ssh\nPortNumber=2222\n").passwordTarget
                == "test@server.example:2222")
        #expect(try session("HostName=192.0.2.7\nUserName=test\n").passwordTarget == "test@192.0.2.7:22")
        #expect(try session("HostName=server.example\nUserName=test\nProxyMethod=0\n").passwordUnavailableReason == nil)
    }

    @Test("Kein Passwort speichern ohne Benutzer, ohne Server, bei Telnet/Raw oder mit Proxy", arguments: [
        ("HostName=server.example\n", "Benutzername"),
        ("UserName=test\n", "Server"),
        ("HostName=server.example\nUserName=test\nProtocol=telnet\n", "SSH"),
        ("HostName=server.example\nUserName=test\nProxyMethod=6\nProxyHost=sprung\n", "Proxy"),
        ("HostName=server.example\nUserName=test\nProxyType=2\n", "Proxy"),
        ("HostName=server.example\nUserName=test\nSSHManualHostKeys=SHA256:abc\n", "Hostschlüssel")
    ])
    func unavailable(text: String, reasonMentions: String) throws {
        let file: SessionFile = try session(text)
        #expect(file.passwordTarget == nil)
        #expect(file.passwordUnavailableReason?.contains(reasonMentions) == true)
    }

    @Test("Schlüsseldatei: leer oder absoluter Pfad ohne Zeilenumbruch")
    func publicKeyFile() throws {
        var file: SessionFile = SessionFile()
        try file.setPublicKeyFile("/tmp/test.ppk")
        #expect(file.publicKeyFile == "/tmp/test.ppk")
        #expect(file.value(forKey: "PublicKeyFile") == "/tmp/test.ppk")
        try file.setPublicKeyFile("")
        #expect(file.publicKeyFile == "")
        #expect(throws: InputError.notAbsolute) { try file.setPublicKeyFile("relativ.ppk") }
        #expect(throws: InputError.controlCharacter(.path)) { try file.setPublicKeyFile("/tmp/a\nProxyMethod=5") }
        #expect(SessionFile.editedKeys.contains("PublicKeyFile"))
    }
}
