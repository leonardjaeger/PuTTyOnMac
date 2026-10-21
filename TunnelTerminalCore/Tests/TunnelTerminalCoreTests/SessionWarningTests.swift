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
        // Telnet-Proxy: der Text geht an den Proxy – seit der Härtung eine Rückfrage (Ziel kann ein Dienst auf dem Mac sein)
        #expect(try warnings("ProxyMethod=4\nProxyTelnetCommand=x\n") == [.telnetProxy(server: "proxy:80", text: "x")])
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
                          .sessionLog])
        #expect(found.allSatisfy { !$0.isDangerous })
        #expect(found.allSatisfy { !$0.message.isEmpty })
    }

    /// M4: LogType 1/2 schreibt die App selbst in ihren Ordner (plink protokolliert ohne Terminal nichts); 3/4 schreibt plink
    /// als SSH-Paketprotokoll an `LogFileName` – mit allem Getippten, auch Passwörtern in der Shell. Zahlen wie plink (`atoi`).
    @Test("Sitzungsprotokoll der App und Paketprotokoll von plink", arguments: [
        ("LogType=1\n", [SessionWarning.sessionLog]), ("LogType=02\n", [.sessionLog]),
        ("LogType=3\nLogFileName=/tmp/p.log\n", [.packetLog("/tmp/p.log")]), ("LogType=4\n", [.packetLog("putty.log")]),
        ("LogType=0\n", []), ("LogType=7\n", [])
    ])
    func logWarnings(text: String, expected: [SessionWarning]) throws {
        #expect(try warnings(text) == expected)
        #expect(SessionWarning.packetLog("/tmp/p.log").message.contains("Eingaben"))
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
        #expect(SessionWarning.sessionLog.blocksPreselection)
        #expect(!SessionWarning.sessionLog.isDangerous)
        #expect(SessionWarning.packetLog("x").blocksPreselection)
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

    /// Härtung (Prüfer-Agent): plink 0.85 startet weitere Befehle mit /bin/sh (proxy/newmain.c, ssh/userauth2-client.c,
    /// unix/local-proxy.c) bzw. schickt beim Telnet-Proxy vorgegebenen Text. Alle sind Rückfragen vor dem Verbinden
    /// und beim Import nicht vorausgewählt – auch über eine Proxy-Sitzung und die Standardeinstellungen.
    @Test("Weitere Befehle auf diesem Mac: PreConnectCommand, AuthPlugin, Telnet-Proxy (Härtung)", arguments: [
        ("PreConnectCommand=touch /tmp/x\n", SessionWarning.preConnectCommand("touch /tmp/x")),
        ("HostName=server.example\nPreConnectCommand=knock %host\\x20%port\n", .preConnectCommand("knock server.example 22")),
        ("Protocol=ssh\nAuthPlugin=/tmp/plugin --arg\n", .authPlugin("/tmp/plugin --arg")),
        ("ProxyType=3\nProxyHost=127.0.0.1\nProxyPort=25\nProxyTelnetCommand=HELO x\\r\\n\n",
         .telnetProxy(server: "127.0.0.1:25", text: "HELO x\r\n"))
    ])
    func moreLocalCommands(text: String, expected: SessionWarning) throws {
        #expect(try warnings(text) == [expected])
        #expect(expected.isDangerous && expected.blocksPreselection)
        #expect(!expected.message.isEmpty)
        // Seriell öffnet keine Netzverbindung: plink startet nichts davon
        #expect(try warnings("Protocol=serial\n" + text).isEmpty)
        let proxy: SessionFile = try SessionFile(contents: Data(text.utf8))
        let main: SessionFile = try SessionFile(contents: Data("ProxyMethod=6\nProxyHost=Sprung\n".utf8))
        #expect(try SessionWarning.requiringConfirmation(for: main) { $0 == "Sprung" ? proxy : nil } == [.viaProxy("Sprung", expected)])
        #expect(try SessionWarning.requiringConfirmation(for: main) { $0 == "Default Settings" ? proxy : nil }
                == [.viaProxy("Default Settings", expected)])
    }

    @Test("Leere Werte und X11-Weiterleitung: kein Befehl, X11 nur als Hinweis wie die Agent-Weiterleitung")
    func emptyCommandsAndX11() throws {
        #expect(try warnings("PreConnectCommand=\nAuthPlugin=\n").isEmpty)
        #expect(try warnings("X11Forward=1\n") == [.x11Forwarding])
        #expect(!SessionWarning.x11Forwarding.isDangerous && !SessionWarning.x11Forwarding.blocksPreselection)
        #expect(try warnings("X11Forward=0\n").isEmpty)
        // Anzeige als Pfad = lokaler Socket (x11disp.c): Rückfrage; ohne Weiterleitung egal
        #expect(try warnings("X11Forward=1\nX11Display=/tmp/.X11-unix/X0\n") == [.x11Socket("/tmp/.X11-unix/X0")])
        #expect(SessionWarning.x11Socket("/x").isDangerous)
        #expect(try warnings("X11Forward=0\nX11Display=/tmp/x\n").isEmpty)
        #expect(try warnings("X11Forward=1\nX11Display=localhost:10\n") == [.x11Forwarding])
    }

    @Test("Standardeinstellungen als SSH-Proxy gelten immer als SSH – auch mit Protocol=serial (Prüfer 2)")
    func defaultSettingsAsProxyAreSSH() throws {
        let defaults: SessionFile = try SessionFile(contents: Data(
            "Protocol=serial\nProxyMethod=5\nProxyTelnetCommand=x\nPreConnectCommand=y\n".utf8))
        let main: SessionFile = try SessionFile(contents: Data("ProxyMethod=6\nProxyHost=sprung.example\n".utf8))
        #expect(try SessionWarning.requiringConfirmation(for: main) { $0 == "Default Settings" ? defaults : nil } == [
            .viaProxy("Default Settings", .localProxyCommand("x")), .viaProxy("Default Settings", .preConnectCommand("y"))
        ])
    }

    @Test("Paketprotokoll von plink: Rückfrage vor jedem Verbinden (schreibt bzw. überschreibt eine Datei, Prüfer 2)")
    func packetLogNeedsConfirmation() throws {
        let file: SessionFile = try SessionFile(contents: Data("LogType=3\nLogFileName=/tmp/p.log\nLogFileClash=1\n".utf8))
        #expect(try SessionWarning.requiringConfirmation(for: file) { _ in nil } == [.packetLog("/tmp/p.log")])
        let appLog: SessionFile = try SessionFile(contents: Data("LogType=2\n".utf8))
        #expect(try SessionWarning.requiringConfirmation(for: appLog) { _ in nil }.isEmpty)
    }

    @Test("Proxy oder entfernte Weiterleitung auf einen lokalen Unix-Socket: nicht verbinden (Härtung)", arguments: [
        "ProxyMethod=3\nProxyHost=/var/run/x.sock\n", "ProxyType=2\nProxyHost=[/tmp/s]\n",
        "ProxyMethod=4\nProxyHost= /tmp/s\n", "ProxyMethod=6\nProxyHost=/tmp/s\n",
        "PortForwardings=R2222=/var/run/x.sock:1\n", "PortForwardings=L8080=localhost:80,4R80=[/tmp/s]:0\n"
    ])
    func localSockets(text: String) throws {
        let file: SessionFile = try SessionFile(contents: Data(text.utf8))
        #expect(throws: InputError.localSocket) { try SessionWarning.requiringConfirmation(for: file) { _ in nil } }
    }

    @Test("Keine lokalen Sockets: Proxy-Befehl mit Pfad, lokale Weiterleitung, Seriell, Server als Name")
    func noLocalSockets() throws {
        for text in ["ProxyMethod=5\nProxyHost=/tmp/s\nProxyTelnetCommand=nc %proxyhost\n", "PortForwardings=L8080=/tmp/s:1\n",
                     "Protocol=serial\nProxyMethod=3\nProxyHost=/tmp/s\n", "ProxyMethod=3\nProxyHost=proxy.server.example\n"] {
            let file: SessionFile = try SessionFile(contents: Data(text.utf8))
            #expect(!file.reachesLocalSocket, "\(text)")
        }
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
        // seit M5: Schleife = Fehler (plink verbände endlos)
        #expect(throws: InputError.proxyLoop) { try SessionWarning.requiringConfirmation(for: loop, load: load) }
        #expect(SessionWarning.viaProxy("B", .localProxyCommand("x")).isDangerous)
        #expect(SessionWarning.viaProxy("B", .localProxyCommand("x")).message.contains("„B“"))
        // Nicht lesbare Proxy-Sitzung: Fehler statt stiller Freigabe
        #expect(throws: InputError.invalidFile) {
            try SessionWarning.requiringConfirmation(for: a) { _ in throw InputError.invalidFile }
        }
    }
}
