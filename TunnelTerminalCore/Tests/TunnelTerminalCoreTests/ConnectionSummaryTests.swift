import Foundation
import Testing
@testable import TunnelTerminalCore

/// Inhalt des Inspektor-Abschnitts „Verbindung“ (Plan 3.1). Nur Platzhalter (S14).
@Suite("Verbindungsübersicht")
struct ConnectionSummaryTests {
    private func file(_ text: String) throws -> SessionFile {
        try SessionFile(contents: Data(text.utf8))
    }

    @Test func quickConnectionShowsServerUserAndAgent() throws {
        let endpoint: Endpoint = try Endpoint(parsing: "test@server.example:2222")
        let summary: ConnectionSummary = ConnectionSummary(file: try SessionFile.quickConnect(to: endpoint, using: .ssh))
        #expect(summary.server == "server.example:2222")
        #expect(summary.user == "test")
        #expect(summary.protocolTitle == "SSH")
        #expect(summary.authentication == "Agent, sonst Passwort")
        #expect(summary.endsWithPassword)
    }

    @Test func missingUserAsksWhenConnecting() throws {
        let summary: ConnectionSummary = ConnectionSummary(file: try file("HostName=192.0.2.1\nProtocol=ssh\n"))
        #expect(summary.server == "192.0.2.1:22")   // ohne PortNumber nimmt PuTTY 22
        #expect(summary.user == nil)
    }

    @Test func keyFileShowsOnlyTheFileName() throws {
        let summary: ConnectionSummary = ConnectionSummary(file: try file(
            "HostName=server.example\nProtocol=ssh\nPortNumber=22\nPublicKeyFile=/Pfad/zum/schluessel.ppk\nTryAgent=0\n"))
        #expect(summary.authentication == "Schlüsseldatei „schluessel.ppk“")
        #expect(!summary.endsWithPassword)
    }

    @Test(arguments: [("TryAgent=0\n", "Passwort"), ("TryAgent=1\n", "Agent, sonst Passwort"),
                      ("TryAgent=00\n", "Passwort"), ("", "Agent, sonst Passwort")])
    func agentFollowsPuTTYNumbers(line: String, expected: String) throws {
        let summary: ConnectionSummary = ConnectionSummary(file: try file("HostName=server.example\nProtocol=ssh\n" + line))
        #expect(summary.authentication == expected)
    }

    @Test func telnetRawAndOthersHaveNoSSHLogin() throws {
        #expect(ConnectionSummary(file: try file("HostName=server.example\nProtocol=telnet\nPortNumber=23\n"))
            .authentication == "Im Terminal (Telnet)")
        #expect(ConnectionSummary(file: try file("HostName=server.example\nProtocol=raw\nPortNumber=7\n"))
            .authentication == "Keine")
        // seit M5 bietet die App Seriell an; andere Verfahren von plink bleiben „Anderes“
        let other: ConnectionSummary = ConnectionSummary(file: try file("HostName=server.example\nProtocol=rlogin\n"))
        #expect(other.protocolTitle == "Anderes (rlogin)")
        #expect(other.authentication == "Keine")
    }

    @Test func ipv6AndHiddenCharactersAreShownSafely() throws {
        let summary: ConnectionSummary = ConnectionSummary(file: try file(
            "HostName=2001:db8::1\nProtocol=ssh\nPortNumber=22\nUserName=te\u{202E}st\n"))
        #expect(summary.server == "[2001:db8::1]:22")
        #expect(summary.user == SessionWarning.visible("te\u{202E}st"))
        #expect(summary.user != "te\u{202E}st")
    }
}
