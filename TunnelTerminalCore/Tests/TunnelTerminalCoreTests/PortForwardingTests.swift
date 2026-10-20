import Foundation
import Testing
@testable import TunnelTerminalCore

/// Port-Weiterleitungen im Format von PuTTY 0.85 (settings.c `gppmap`/`wmap`, ssh/portfwd.c), Plan M5.
@Suite("Port-Weiterleitungen")
struct PortForwardingTests {
    private func file(_ value: String) throws -> SessionFile {
        try SessionFile(contents: Data("Protocol=ssh\nPortForwardings=\(value)\n".utf8))
    }

    @Test("Liest lokal, entfernt und dynamisch wie plink (gemessen in M5)")
    func readsAllKinds() throws {
        let list: [PortForwarding] = try file("L28080=127.0.0.1:28081,D28082,R28083=server.example:80").portForwardings
        #expect(list.map(\.kind) == [.local, .dynamic, .remote])
        #expect(list.map(\.listenPort) == [28080, 28082, 28083])
        #expect(list[0].target == "127.0.0.1:28081")
        #expect(list[1].target == "")
        #expect(list[2].target == "server.example:80")
    }

    @Test("Adressfamilie, Bindadresse und Maskierung mit „\\“ bleiben erhalten")
    func readsDetails() throws {
        let list: [PortForwarding] = try file(#"4L127.0.0.1:8080=[::1]:80,6D[::1]:1080,R2222=a\,b:22"#).portForwardings
        #expect(list.count == 3)
        #expect(list[0].addressFamily == "4" && list[0].listen == "127.0.0.1:8080" && list[0].listenPort == 8080)
        #expect(list[0].target == "[::1]:80")
        #expect(list[1].kind == .dynamic && list[1].addressFamily == "6" && list[1].listenPort == 1080)
        #expect(list[2].target == "a,b:22")
    }

    @Test("Wie PuTTY: „D“ irgendwo im Schlüssel heißt dynamisch, derselbe Schlüssel zweimal – der letzte gilt")
    func plinkQuirks() throws {
        let list: [PortForwarding] = try file("L1080=server.example:80,D1080,Lx=y").portForwardings
        #expect(list.count == 2)
        #expect(list[0].kind == .dynamic && list[0].listenPort == 1080)
        #expect(list[1].listenPort == nil)   // Dienstname statt Zahl: kein Port zum Prüfen
    }

    @Test("Ohne Eintrag oder leer: keine Weiterleitungen")
    func empty() throws {
        #expect(SessionFile().portForwardings.isEmpty)
        #expect(try file("").portForwardings.isEmpty)
    }

    @Test("Schreiben im Format von PuTTY, Rundlauf ergibt dieselbe Liste")
    func writesAndReadsBack() throws {
        var session: SessionFile = SessionFile()
        let list: [PortForwarding] = [
            try PortForwarding(kind: .local, port: 8080, targetHost: "server.example", targetPort: 80),
            try PortForwarding(kind: .dynamic, port: 1080),
            try PortForwarding(kind: .remote, port: 2222, targetHost: "::1", targetPort: 22)
        ]
        try session.setPortForwardings(list)
        #expect(session.value(forKey: "PortForwardings") == "L8080=server.example:80,D1080=,R2222=[::1]:22")
        #expect(session.portForwardings == list)
        let imported: [PortForwarding] = try file(#"4L127.0.0.1:8080=a\,b:22"#).portForwardings
        try session.setPortForwardings(imported)
        #expect(session.value(forKey: "PortForwardings") == #"4L127.0.0.1:8080=a\,b:22"#)
    }

    @Test("Neue Einträge: Ports 1–65535, Ziel nach den Server-Regeln (S3/S4)", arguments: [
        (0, "server.example", 80), (65_536, "server.example", 80), (8080, "server.example", 0),
        (8080, "-proxycmd", 80), (8080, "a,b", 80), (8080, "a\nb", 80), (8080, "", 80)
    ])
    func rejectsInvalid(port: Int, host: String, targetPort: Int) {
        #expect(throws: InputError.self) {
            try PortForwarding(kind: .local, port: port, targetHost: host, targetPort: targetPort)
        }
    }

    @Test("Beschreibung für Inspektor und Editor")
    func titles() throws {
        #expect(try PortForwarding(kind: .local, port: 8080, targetHost: "server.example", targetPort: 80).title
            == "8080 → server.example:80")
        #expect(try PortForwarding(kind: .dynamic, port: 1080).title == "1080 (SOCKS-Proxy)")
    }

    @Test("Lokale Ports, die vor dem Verbinden frei sein müssen (lokal und dynamisch, nur Zahlen)")
    func localPorts() throws {
        let session: SessionFile = try file("L8080=a:1,R9000=b:2,D1080,L127.0.0.1:7000=c:3,Lsmtp=d:4")
        #expect(session.localListenPorts == [8080, 1080, 7000])
    }

    @Test("Warnung, wenn lokale Ports auch Verbindungen anderer Rechner annehmen")
    func acceptAllWarning() throws {
        var session: SessionFile = try file("L8080=a:1")
        #expect(!session.warnings.contains(.openLocalPorts))
        session.setFlag(true, for: .localPortAcceptAll)
        #expect(session.warnings.contains(.openLocalPorts))
    }
}

/// Befunde des Prüfer-Agenten (M5): Lesen wie plink, offene Ports, doppelte Ports, beschädigte Werte.
@Suite("Port-Weiterleitungen: Randfälle")
struct PortForwardingEdgeTests {
    private func file(_ text: String) throws -> SessionFile { try SessionFile(contents: Data(text.utf8)) }

    @Test("Ein zweites „=“ beginnt den Wert neu, wie plinks gppmap")
    func secondEquals() throws {
        #expect(try file("PortForwardings=L8080=a=b:1\n").portForwardings[0].target == "b:1")
    }

    @Test("Eigene Bindadresse außerhalb von Loopback öffnet den Port ins Netz – Warnung, nicht vorausgewählt", arguments: [
        ("D0.0.0.0:1080", true), ("L[::]:8080=a:1", true), ("L192.0.2.1:8080=a:1", true),
        ("L127.0.0.1:8080=a:1", false), ("L[::1]:8080=a:1", false), ("Lname.example:8080=a:1", false), ("R0.0.0.0:80=a:1", false)
    ])
    func bindAddress(_ rule: String, opens: Bool) throws {
        let session: SessionFile = try file("PortForwardings=\(rule)\n")
        #expect(session.warnings.contains(.openLocalPorts) == opens)
        #expect(SessionWarning.openLocalPorts.blocksPreselection)
        if opens { #expect(session.localListenPorts.isEmpty) }   // dort prüft die App den Port nicht
    }

    @Test("Mit „auch für andere Rechner“ prüft die App keine Ports")
    func acceptAllSkipsCheck() throws {
        var session: SessionFile = try file("PortForwardings=L8080=a:1\n")
        session.setFlag(true, for: .localPortAcceptAll)
        #expect(session.localListenPorts.isEmpty)
    }

    @Test("Derselbe lokale Port zweimal wird abgelehnt (lokal und dynamisch teilen sich die Ports)")
    func duplicatePort() throws {
        var session: SessionFile = try file("PortForwardings=D1080\n")
        #expect(throws: InputError.forwardingTaken) {
            try session.addPortForwarding(try PortForwarding(kind: .local, port: 1080, targetHost: "a.example", targetPort: 1))
        }
        try session.addPortForwarding(try PortForwarding(kind: .remote, port: 1080, targetHost: "a.example", targetPort: 1))
        #expect(session.portForwardings.count == 2)
    }

    @Test("„\\“ am Ende oder unbestimmter Proxy: nicht verbinden (plink läse über das Ende bzw. einen ungesetzten Wert)",
          arguments: ["PortForwardings=L1=a\\\n", "ProxyType=7\n", "ProxyMethod=9\nProxyType=5\n"])
    func failsClosed(_ text: String) throws {
        let session: SessionFile = try file(text)
        #expect(throws: InputError.invalidFile) { try SessionWarning.requiringConfirmation(for: session) { _ in nil } }
    }

    @Test("Gültige Werte bleiben verbindbar", arguments: ["PortForwardings=L1=a\\\\\n", "ProxyMethod=2\nProxyType=9\n", "ProxyType=4\n"])
    func staysConnectable(_ text: String) throws {
        let session: SessionFile = try file(text)
        _ = try SessionWarning.requiringConfirmation(for: session) { _ in nil }
    }

    @Test("Unbestimmter Proxy: kein gespeichertes Passwort")
    func undefinedProxyNoPassword() throws {
        let session: SessionFile = try file("HostName=server.example\nUserName=test\nProxyType=7\n")
        #expect(session.hasUndefinedProxy && session.passwordTarget == nil)
    }

    @Test("Seriell: kein Proxy-Befehl (plink öffnet keine Netzverbindung); Pfad außerhalb von /dev wird gewarnt")
    func serialImport() throws {
        let session: SessionFile = try file("Protocol=serial\nSerialLine=/tmp/datei\nProxyMethod=5\nProxyTelnetCommand=x\n")
        #expect(!session.warnings.contains { $0.isDangerous })
        #expect(session.warnings.contains(.serialDevice("/tmp/datei")))
    }
}
