import Foundation
import Testing
@testable import TunnelTerminalCore

/// Die im Editor bearbeitbaren Einstellungen. Alle anderen Zeilen bleiben byte-gleich (Plan M2).
@Suite("Sitzungseinstellungen")
struct SessionSettingsTests {
    /// Gekürzte, aber typische Datei von PuTTY 0.85 für Unix (Platzhalter nach S14), mit Eigenheiten:
    /// unbekannter Schlüssel, Zeile ohne „=“, CR am Zeilenende, ungültiges UTF-8.
    private static let realistic: Data = {
        var data: Data = Data("""
        Present=1
        HostName=server.example
        LogFileName=putty.log
        LogType=0
        Protocol=ssh
        PortNumber=22
        CloseOnExit=1
        PingInterval=0
        PingIntervalSecs=0
        TCPNoDelay=1
        TCPKeepalives=0
        TerminalType=xterm
        TerminalSpeed=38400,38400
        UserName=test
        ProxyMethod=none
        ProxyHost=proxy
        ProxyTelnetCommand=connect %host %port\\n
        Compression=0
        AgentFwd=0
        RemoteCommand=
        Cipher=aes,chacha20,aesgcm,3des,WARN,des,blowfish,arcfour
        KEX=ntru-curve25519,mlkem-curve25519,mlkem-nist,ecdh,dh-gex-sha1,dh-group18-sha512,WARN,rsa,dh-group1-sha1
        Colour0=187,187,187
        Font=server:fixed
        WordNess0=0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ZukunftsSchluessel=wert\r
        kommentarzeile ohne gleich

        """.utf8)
        data.append(contentsOf: [0x58, 0x3D, 0xFF, 0xFE, 0x0A])   // „X=“ mit ungültigem UTF-8
        return data
    }()

    @Test("Fehlende Werte: PuTTYs eingebaute Vorgaben")
    func defaults() {
        let file: SessionFile = SessionFile()
        #expect(file.hostName == "")
        #expect(file.portNumber == 22)
        #expect(file.connectionProtocol == .ssh)
        #expect(file.userName == "")
        #expect(file.terminalType == "xterm")
        #expect(file.keepaliveSeconds == 0)
        #expect(!file.tcpKeepalives && !file.compression && !file.agentForwarding)
        #expect(file.remoteCommand == "")
    }

    @Test("Liest die Werte einer echten Datei")
    func readsRealisticFile() throws {
        let file: SessionFile = try SessionFile(contents: Self.realistic)
        #expect(file.hostName == "server.example")
        #expect(file.userName == "test")
        #expect(file.otherEntryCount == 15)   // LogType bearbeitet der Editor seit M4 (Sitzungsprotokoll)
    }

    @Test("Bearbeiten ändert nur die bearbeiteten Zeilen; alles andere bleibt byte-gleich")
    func editsInPlace() throws {
        var file: SessionFile = try SessionFile(contents: Self.realistic)
        try file.setHostName("192.0.2.10")
        try file.setPortNumber(2222)
        try file.setUserName("")
        try file.setTerminalType("xterm-256color")
        try file.setKeepaliveSeconds(30)
        file.setFlag(true, for: .compression)
        file.setFlag(true, for: .agentForwarding)
        file.setFlag(true, for: .tcpKeepalives)
        try file.setRemoteCommand("uptime")
        file.setConnectionProtocol(.telnet)

        var expected: [UInt8] = [UInt8](Self.realistic)
        for (old, new) in [("HostName=server.example", "HostName=192.0.2.10"), ("PortNumber=22", "PortNumber=2222"),
                           ("UserName=test", "UserName="), ("TerminalType=xterm\n", "TerminalType=xterm-256color\n"),
                           ("PingIntervalSecs=0", "PingIntervalSecs=30"), ("Compression=0", "Compression=1"),
                           ("AgentFwd=0", "AgentFwd=1"), ("TCPKeepalives=0", "TCPKeepalives=1"),
                           ("RemoteCommand=\n", "RemoteCommand=uptime\n"), ("Protocol=ssh", "Protocol=telnet")] {
            let range: Range<Int> = try #require(expected.firstRange(of: Array(old.utf8)))
            expected.replaceSubrange(range, with: Array(new.utf8))
        }
        #expect([UInt8](file.contents) == expected)
        #expect(file.connectionProtocol == .telnet)
        #expect(file.keepaliveSeconds == 30)
    }

    @Test("Keepalive wie PuTTY: Minuten und Sekunden in zwei Schlüsseln (Kompatibilität mit 0.50)")
    func keepaliveInTwoKeys() throws {
        var file: SessionFile = SessionFile()
        try file.setValue("2", forKey: "PingInterval")
        try file.setValue("5", forKey: "PingIntervalSecs")
        #expect(file.keepaliveSeconds == 125)
        try file.setKeepaliveSeconds(90)
        #expect(file.contents == Data("PingInterval=1\nPingIntervalSecs=30\n".utf8))
        #expect(throws: InputError.outOfRange(.keepalive)) { try file.setKeepaliveSeconds(86_401) }
    }

    @Test("Unbekanntes Protokoll wird nicht als SSH ausgegeben")
    func unknownProtocol() throws {
        var file: SessionFile = SessionFile()
        try file.setValue("serial", forKey: "Protocol")
        #expect(file.connectionProtocol == nil)
    }

    @Test("Ungültige Eingaben werden abgelehnt (S3, S4)")
    func rejectsInvalidInput() {
        var file: SessionFile = SessionFile()
        #expect(throws: InputError.leadingDash(.host)) { try file.setHostName("-oProxyCommand=x") }
        #expect(throws: InputError.invalidCharacter(.host)) { try file.setHostName("a@b") }
        #expect(throws: InputError.whitespace(.user)) { try file.setUserName("a b") }
        #expect(throws: InputError.leadingDash(.user)) { try file.setUserName("-l") }
        #expect(throws: InputError.invalidPort) { try file.setPortNumber(0) }
        #expect(throws: InputError.invalidPort) { try file.setPortNumber(65536) }
        #expect(throws: InputError.outOfRange(.keepalive)) { try file.setKeepaliveSeconds(-1) }
        #expect(throws: InputError.whitespace(.terminalType)) { try file.setTerminalType("xterm 256") }
        #expect(throws: InputError.controlCharacter(.value)) { try file.setRemoteCommand("a\nb") }
        #expect(file == SessionFile())
    }

    @Test("Leerer Server und Benutzer sind erlaubt (wie in PuTTY)")
    func acceptsEmpty() throws {
        var file: SessionFile = SessionFile()
        try file.setHostName("")
        try file.setUserName("")
        #expect(file.contents == Data("HostName=\nUserName=\n".utf8))
    }

    @Test("Proxy anzeigen und abschalten (auch das alte ProxyType)")
    func proxy() throws {
        var file: SessionFile = try SessionFile(contents: Data("ProxyType=4\nProxyTelnetCommand=x\n".utf8))
        #expect(file.proxyDescription == "Lokaler Befehl auf diesem Mac")
        #expect(file.warnings.contains { $0.isDangerous })
        file.disableProxy()
        #expect(file.proxyDescription == nil)
        #expect(file.warnings.isEmpty)
        #expect(file.contents == Data("ProxyType=0\nProxyTelnetCommand=x\nProxyMethod=0\n".utf8))
        #expect(SessionFile().proxyDescription == nil)
        var ssh: SessionFile = SessionFile()
        try ssh.setValue("6", forKey: "ProxyMethod")
        try ssh.setValue("Sprung", forKey: "ProxyHost")
        #expect(ssh.proxyDescription == "SSH über „Sprung“")
    }

    /// Fehler aus M3 (gemessen mit plink 0.85, docs/M3-Recherche.md 3.3): Ohne bekanntes `Protocol` nimmt plink SSH auf
    /// Port 22 und ignoriert `PortNumber` (`settings.c`, `load_open_settings`). Inspektor, Hostschlüssel-Abschnitt und
    /// Passwort-Bindung müssen denselben Port sehen wie plink.
    @Test("Port wie plink: ohne bekanntes Protocol immer 22", arguments: [
        ("HostName=a\nPortNumber=2222\n", 22),
        ("HostName=a\nPortNumber=2222\nProtocol=unbekannt\n", 22),
        ("HostName=a\nPortNumber=2222\nProtocol=ssh\n", 2222),
        ("HostName=a\nPortNumber=23\nProtocol=telnet\n", 23),
        ("HostName=a\nProtocol=raw\n", 22)
    ])
    func portLikePlink(text: String, port: Int) throws {
        #expect(try SessionFile(contents: Data(text.utf8)).portNumber == port)
    }

    @Test("Port setzen schreibt Protocol=ssh dazu, wenn es fehlt (sonst wirkte der Port nicht)")
    func settingPortMakesItEffective() throws {
        var file: SessionFile = try SessionFile(contents: Data("HostName=a\n".utf8))
        try file.setPortNumber(2222)
        #expect(file.value(forKey: "Protocol") == "ssh")
        #expect(file.portNumber == 2222)
        var telnet: SessionFile = try SessionFile(contents: Data("Protocol=telnet\n".utf8))
        try telnet.setPortNumber(2323)
        #expect(telnet.value(forKey: "Protocol") == "telnet")
    }
}

/// M4: Profil und Sitzungsprotokoll je Sitzung.
@Suite("Sitzungseinstellungen M4")
struct SessionTerminalSettingsTests {
    @Test("Profil-Kennung: lesen, setzen, entfernen; Unsinn zählt als kein Profil")
    func profile() throws {
        var file: SessionFile = SessionFile()
        #expect(file.profileID == nil)
        let id: UUID = UUID()
        try file.setProfileID(id)
        #expect(file.profileID == id)
        #expect(file.value(forKey: "TunnelTerminalProfile") == id.uuidString)
        try file.setProfileID(nil)
        #expect(file.value(forKey: "TunnelTerminalProfile") == nil)
        try file.setValue("kein-uuid", forKey: "TunnelTerminalProfile")
        #expect(file.profileID == nil)
    }

    /// LogType wie PuTTY (putty.h): 1 druckbare, 2 alle Ausgaben – beides schreibt die App selbst, weil plink ohne
    /// Terminal nichts protokolliert (Machbarkeit M4). 3/4 sind SSH-Paketprotokolle von plink, keine Sitzungsprotokolle.
    @Test("Sitzungsprotokoll: an bei LogType 1 und 2, Schalter setzt 2 bzw. 0", arguments: [
        ("0", false), ("1", true), ("2", true), ("02", true), ("3", false), ("4", false), ("x", false)
    ])
    func sessionLog(logType: String, enabled: Bool) throws {
        var file: SessionFile = SessionFile()
        try file.setValue(logType, forKey: "LogType")
        #expect(file.sessionLogEnabled == enabled)
        file.setSessionLog(true)
        #expect(file.value(forKey: "LogType") == "2")
        file.setSessionLog(false)
        #expect(file.value(forKey: "LogType") == "0")
    }
}
