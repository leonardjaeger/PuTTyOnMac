import Foundation
import Testing
@testable import TunnelTerminalCore

/// Proxy, Jump-Host und Seriell im Editor (Plan M5); Schlüssel und Vorgaben wie conf.h von PuTTY 0.85.
@Suite("Proxy und Seriell")
struct ProxySerialTests {
    @Test("Proxy setzen: Art, Server, Port, Benutzer")
    func proxy() throws {
        var file: SessionFile = SessionFile()
        #expect(file.proxyKind == ProxyKind.none)
        try file.setProxyKind(.socks5)
        try file.setProxyHost("proxy.example")
        try file.setProxyPort(1080)
        try file.setProxyUsername("test")
        #expect(file.value(forKey: "ProxyMethod") == "2")
        #expect(file.proxyKind == .socks5 && file.proxyHost == "proxy.example" && file.proxyPort == 1080)
        #expect(file.proxyUsername == "test")
        #expect(file.proxyDescription == "SOCKS 5 über proxy.example")
        #expect(file.passwordTarget == nil)   // mit Proxy nie ein gespeichertes Passwort (M3)
        #expect(ConnectionSummary(file: file).proxy == "SOCKS 5 über proxy.example")
        #expect(ConnectionSummary(file: SessionFile()).proxy == nil)
    }

    @Test("Vorgaben wie PuTTY: Server „proxy“, Port 80; altes ProxyType wird gelesen")
    func proxyDefaults() throws {
        let old: SessionFile = try SessionFile(contents: Data("ProxyType=1\n".utf8))
        #expect(old.proxyKind == .http)
        #expect(old.proxyHost == "proxy" && old.proxyPort == 80)
        let unknown: SessionFile = try SessionFile(contents: Data("ProxyMethod=7\n".utf8))
        #expect(unknown.proxyKind == .ssh)
    }

    @Test("Ungültige Proxy-Werte werden abgelehnt (S3/S4)")
    func proxyRejects() {
        var file: SessionFile = SessionFile()
        #expect(throws: InputError.self) { try file.setProxyHost("-oProxyCommand=x") }
        #expect(throws: InputError.self) { try file.setProxyPort(0) }
        #expect(throws: InputError.self) { try file.setProxyUsername("a b") }
        #expect(throws: InputError.self) { try file.setProxyCommand("nc %host\n%port") }
    }

    @Test("Jump-Host: gespeicherte Sitzung als SSH-Proxy (ProxyMethod 6, ProxyHost = Sitzungsname)")
    func jumpHost() throws {
        var file: SessionFile = SessionFile()
        try file.setJumpHost(sessionNamed: "Sprung/Mac")
        #expect(file.value(forKey: "ProxyMethod") == "6")
        #expect(file.value(forKey: "ProxyHost") == "Sprung/Mac")
        #expect(file.proxyKind == .ssh)
        #expect(file.warnings.contains(.proxySession("Sprung/Mac")))
        #expect(throws: InputError.self) { try file.setJumpHost(sessionNamed: "-load") }
        // zurück zu SOCKS: der Sitzungsname gilt nicht als Proxy-Server (sonst SOCKS zu „Sprung/Mac“)
        try file.setProxyKind(.socks5)
        #expect(file.value(forKey: "ProxyHost") == nil && file.proxyHost == "proxy")
        try file.setProxyHost("proxy.example")
        try file.setProxyKind(.http)
        #expect(file.proxyHost == "proxy.example")
    }

    @Test("Proxy-Schleifen werden erkannt, bevor plink endlos verbindet (M5 gemessen)")
    func proxyLoops() throws {
        func session(proxy: String) throws -> SessionFile {
            var file: SessionFile = SessionFile()
            try file.setJumpHost(sessionNamed: proxy)
            return file
        }
        let sessions: [String: SessionFile] = ["A": try session(proxy: "A"), "B": try session(proxy: "C"),
                                               "C": try session(proxy: "B"), "D": try session(proxy: "E"), "E": SessionFile()]
        let load: (String) -> SessionFile? = { sessions[$0] }
        #expect(throws: InputError.proxyLoop) { try SessionWarning.requiringConfirmation(for: sessions["A"]!, named: "A", load: load) }
        #expect(throws: InputError.proxyLoop) { try SessionWarning.requiringConfirmation(for: sessions["B"]!, named: "B", load: load) }
        #expect(try SessionWarning.requiringConfirmation(for: sessions["D"]!, named: "D", load: load).isEmpty)
    }

    @Test("Lokaler Befehl: wird gespeichert und bleibt eine Gefahr mit Rückfrage (S4)")
    func localCommand() throws {
        var file: SessionFile = SessionFile()
        try file.setProxyKind(.localCommand)
        try file.setProxyCommand("nc %host %port")
        #expect(file.proxyCommand == "nc %host %port")
        #expect(file.warnings.contains(.localProxyCommand("nc  22")))
        #expect(file.warnings.contains { $0.isDangerous })
    }

    @Test("Proxy für Ziele auf diesem Mac (ProxyLocalhost) als Schalter")
    func proxyLocalhost() {
        var file: SessionFile = SessionFile()
        #expect(!file.isOn(.proxyLocalhost))
        file.setFlag(true, for: .proxyLocalhost)
        #expect(file.value(forKey: "ProxyLocalhost") == "1")
    }

    @Test("Seriell: Vorgaben wie PuTTY (9600, 8 Datenbits, 1 Stoppbit, keine Parität, XON/XOFF)")
    func serialDefaults() throws {
        var file: SessionFile = SessionFile()
        file.setConnectionProtocol(.serial)
        #expect(file.connectionProtocol == .serial)
        #expect(file.serialLine == "" && file.serialSpeed == 9600 && file.serialDataBits == 8)
        #expect(file.serialStopBits == 1 && file.serialParity == SerialParity.none && file.serialFlowControl == .xonXoff)
        #expect(file.passwordTarget == nil && file.hostKeyServer == nil)
    }

    @Test("Seriell setzen: Gerät, Geschwindigkeit, Datenbits, Stoppbits, Parität, Flusskontrolle")
    func serialSetters() throws {
        var file: SessionFile = SessionFile()
        try file.setSerialLine("/dev/cu.usbserial-1")
        try file.setSerialSpeed(115_200)
        try file.setSerialDataBits(7)
        try file.setSerialStopBits(2)
        file.setSerialParity(.even)
        file.setSerialFlowControl(.rtsCts)
        #expect(file.value(forKey: "SerialLine") == "/dev/cu.usbserial-1")
        #expect(file.value(forKey: "SerialSpeed") == "115200")
        #expect(file.value(forKey: "SerialDataBits") == "7")
        #expect(file.value(forKey: "SerialStopHalfbits") == "4")
        #expect(file.value(forKey: "SerialParity") == "2")
        #expect(file.value(forKey: "SerialFlowControl") == "2")
        #expect(file.serialStopBits == 2 && file.serialParity == .even && file.serialFlowControl == .rtsCts)
        #expect(file.listAddress == "")   // Protokoll noch SSH: Server
        file.setConnectionProtocol(.serial)
        #expect(file.listAddress == "/dev/cu.usbserial-1")
    }

    @Test("Seriell lehnt Geräte außerhalb von /dev und ungültige Werte ab", arguments: [
        "/etc/passwd", "dev/cu.x", "/dev/../etc/passwd", "/dev/cu.\nx", "-/dev/cu.x", "/dev/"
    ])
    func serialRejectsLine(_ line: String) {
        var file: SessionFile = SessionFile()
        #expect(throws: InputError.self) { try file.setSerialLine(line) }
    }

    @Test("Seriell lehnt Zahlen außerhalb von plinks Bereichen ab")
    func serialRejectsNumbers() {
        var file: SessionFile = SessionFile()
        #expect(throws: InputError.self) { try file.setSerialSpeed(0) }
        #expect(throws: InputError.self) { try file.setSerialDataBits(9) }
        #expect(throws: InputError.self) { try file.setSerialStopBits(3) }
    }

    @Test("Inspektor: serielle Verbindung zeigt Gerät und Geschwindigkeit, keine Anmeldung")
    func serialSummary() throws {
        var file: SessionFile = SessionFile()
        file.setConnectionProtocol(.serial)
        try file.setSerialLine("/dev/cu.usbserial-1")
        try file.setSerialSpeed(115_200)
        let summary: ConnectionSummary = ConnectionSummary(file: file)
        #expect(summary.server == "/dev/cu.usbserial-1, 115200 Baud")
        #expect(summary.protocolTitle == "Seriell")
        #expect(summary.authentication == "Keine")
        #expect(summary.user == nil && !summary.showsUser)
    }

    @Test("Inspektor: Weiterleitungen nur bei SSH")
    func summaryForwardings() throws {
        var file: SessionFile = try SessionFile(contents: Data("PortForwardings=L8080=a:1\n".utf8))
        #expect(ConnectionSummary(file: file).portForwardings.count == 1)
        #expect(ConnectionSummary(file: file).showsTunnels)
        file.setConnectionProtocol(.telnet)
        #expect(!ConnectionSummary(file: file).showsTunnels)
    }

    @Test("Die Schnellverbindung bietet Seriell nicht an")
    func quickConnectCases() {
        #expect(ConnectionProtocol.quickConnectCases == [.ssh, .telnet, .raw])
        #expect(ConnectionProtocol.serial.title == "Seriell")
    }
}
