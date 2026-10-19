import Foundation
import Testing
@testable import TunnelTerminalCore

/// Server, Benutzer und Port so, wie plink sie aus einer gespeicherten Sitzung liest (`prepare_session` in
/// sessprep.c, `ssh_hostport_setup` in ssh.c). Daran hängen das gespeicherte Passwort (S1) und die Hostschlüssel
/// im Inspektor (S5) – weicht die App von plink ab, gälte beides für den falschen Rechner.
@Suite("Adresse wie plink")
struct PlinkAddressTests {
    private func session(_ text: String) throws -> SessionFile {
        try SessionFile(contents: Data(text.utf8))
    }

    @Test("Ein benutzer@ vor dem Server ersetzt UserName – auch für das Passwort-Ziel")
    func userPrefix() throws {
        let file: SessionFile = try session("HostName=other@server.example\nUserName=test\n")
        #expect(file.passwordTarget == "other@server.example:22")
        // plink nimmt das letzte „@“
        #expect(try session("HostName=a@b@server.example\nUserName=test\n").passwordTarget == "a@b@server.example:22")
        #expect(try session("HostName=@server.example\nUserName=test\n").passwordUnavailableReason?.contains("Benutzername") == true)
    }

    @Test("Leerzeichen und ein einzelnes :… nach dem Server zählen nicht")
    func trimming() throws {
        #expect(try session("HostName= server.example:99 \nUserName=test\n").passwordTarget == "test@server.example:22")
        #expect(try session("HostName=2001:db8::1\nUserName=test\n").passwordTarget == "test@2001:db8::1:22")
        #expect(try session("HostName=[2001:db8::1]:99\nUserName=test\n").passwordTarget == "test@[2001:db8::1]:22")
    }

    @Test("Hostschlüssel-Suche: Server wie plink, eckige Klammern um IPv6 weg", arguments: [
        ("HostName=server.example\nProtocol=ssh\nPortNumber=2222\n", "server.example", 2222),
        ("HostName=test@server.example:99\n", "server.example", 22),
        ("HostName=[2001:db8::1]\n", "2001:db8::1", 22),
        ("HostName=2001:db8::1\n", "2001:db8::1", 22),
        ("HostName=server.example\nLogicalHostName=alias.example:2200\n", "alias.example", 2200),
        ("HostName=server.example\nLogicalHostName=alias.example\nProtocol=ssh\nPortNumber=2222\n", "alias.example", 22)
    ])
    func hostKeyServer(text: String, host: String, port: Int) throws {
        let server: (host: String, port: Int)? = try session(text).hostKeyServer
        #expect(server?.host == host)
        #expect(server?.port == port)
    }

    @Test("Keine Hostschlüssel-Suche ohne Server oder ohne SSH")
    func noHostKeyServer() throws {
        #expect(try session("Protocol=ssh\n").hostKeyServer == nil)
        #expect(try session("HostName= \n").hostKeyServer == nil)
        #expect(try session("HostName=server.example\nProtocol=telnet\n").hostKeyServer == nil)
    }
}
