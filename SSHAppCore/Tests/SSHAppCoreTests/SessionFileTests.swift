import Foundation
import Testing
@testable import SSHAppCore

/// PuTTY-Sitzungsdateien: Format wie `unix/storage.c` (docs/M1-Recherche.md 1.1–1.3), Regel S4.
@Suite("Sitzungsdatei")
struct SessionFileTests {
    private func file(_ text: String) throws -> SessionFile {
        try SessionFile(contents: Data(text.utf8))
    }

    @Test("Werte lesen: erster Treffer gewinnt, Wert endet an CR, Wert darf = enthalten")
    func readsLikePuTTY() throws {
        let session: SessionFile = try file("HostName=server.example\r\nRemoteCommand=a=b\nHostName=other\nOhneGleich\n")
        #expect(session.value(forKey: "HostName") == "server.example")
        #expect(session.value(forKey: "RemoteCommand") == "a=b")
        #expect(session.value(forKey: "hostname") == nil)
        #expect(session.value(forKey: "OhneGleich") == nil)
    }

    @Test("Rundlauf: unbekannte Schlüssel und Eigenheiten bleiben byte-gleich", arguments: [
        "", "A=1\n", "A=1", "A=1\r\nB=2\r\n", "Kommentar ohne Gleich\nX=ä\n", "\n\nA=\n",
        "Colour0=187,187,187\nWordness0=0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0\n"
    ])
    func roundTrip(_ text: String) throws {
        let data: Data = Data(text.utf8)
        #expect(try SessionFile(contents: data).contents == data)
    }

    @Test("Ungültiges UTF-8 bleibt beim Rundlauf erhalten")
    func roundTripsNonUTF8() throws {
        let data: Data = Data([0x41, 0x3D, 0xE4, 0x0A])   // „A=ä“ in Latin-1
        #expect(try SessionFile(contents: data).contents == data)
    }

    @Test("Datei mit NUL-Byte wird abgelehnt")
    func rejectsNul() {
        #expect(throws: InputError.invalidFile) { try SessionFile(contents: Data([0x41, 0x3D, 0x00, 0x0A])) }
    }

    @Test("Setzen ersetzt den ersten Treffer und lässt den Rest unverändert")
    func setReplacesFirst() throws {
        var session: SessionFile = try file("A=1\nB=2\nA=3\n")
        try session.setValue("neu", forKey: "A")
        #expect(session.contents == Data("A=neu\nB=2\nA=3\n".utf8))
        try session.setValue("4", forKey: "C")
        #expect(session.contents == Data("A=neu\nB=2\nA=3\nC=4\n".utf8))
    }

    @Test("Anhängen an eine Datei ohne letztes Zeilenende")
    func appendAfterMissingNewline() throws {
        var session: SessionFile = try file("A=1")
        try session.setValue("2", forKey: "B")
        #expect(session.contents == Data("A=1\nB=2\n".utf8))
    }

    @Test("Werte mit Zeilenumbruch oder NUL werden nie geschrieben (S4)", arguments: [
        "x\nProxyMethod=5", "x\rProxyMethod=5", "x\u{0}y"
    ])
    func rejectsBreakingValues(_ value: String) throws {
        var session: SessionFile = SessionFile()
        #expect(throws: InputError.controlCharacter(.value)) { try session.setValue(value, forKey: "HostName") }
        #expect(session.contents.isEmpty)
    }

    @Test("Ungültige Schlüssel werden abgelehnt", arguments: ["", "A=B", "A\nB", "A\rB", "A\u{0}"])
    func rejectsBadKeys(_ key: String) {
        var session: SessionFile = SessionFile()
        #expect(throws: InputError.self) { try session.setValue("1", forKey: key) }
    }

    @Test("Dateinamen wie PuTTY: nur + - . @ _ und ASCII-Buchstaben/Ziffern bleiben")
    func fileNames() {
        #expect(SessionFile.fileName(forSessionNamed: "Default Settings") == "Default%20Settings")
        #expect(SessionFile.fileName(forSessionNamed: "") == "Default%20Settings")
        #expect(SessionFile.fileName(forSessionNamed: "a+b-c.d@e_f09AZ") == "a+b-c.d@e_f09AZ")
        #expect(SessionFile.fileName(forSessionNamed: "x/y%z:") == "x%2Fy%25z%3A")
        #expect(SessionFile.fileName(forSessionNamed: "ä") == "%C3%A4")
    }

    @Test("Schnellverbindung schreibt alle Werte, die plink braucht")
    func quickConnect() throws {
        let endpoint: Endpoint = try Endpoint(parsing: "test@server.example")
        let session: SessionFile = try SessionFile.quickConnect(to: endpoint, using: .ssh)
        #expect(session.value(forKey: "HostName") == "server.example")
        #expect(session.value(forKey: "UserName") == "test")
        #expect(session.value(forKey: "Protocol") == "ssh")
        #expect(session.value(forKey: "PortNumber") == "22")
        // plink 0.85 übernimmt $TERM nicht (M0, B11)
        #expect(session.value(forKey: "TerminalType") == "xterm-256color")
        #expect(session.value(forKey: "Present") == "1")
    }

    @Test("Standardports je Protokoll; Raw braucht einen Port")
    func quickConnectPorts() throws {
        let plain: Endpoint = try Endpoint(parsing: "server.example")
        #expect(try SessionFile.quickConnect(to: plain, using: .telnet).value(forKey: "PortNumber") == "23")
        #expect(throws: InputError.portRequired) { try SessionFile.quickConnect(to: plain, using: .raw) }
        let withPort: Endpoint = try Endpoint(parsing: "server.example:7")
        let raw: SessionFile = try SessionFile.quickConnect(to: withPort, using: .raw)
        #expect(raw.value(forKey: "PortNumber") == "7")
        #expect(raw.value(forKey: "Protocol") == "raw")
        #expect(raw.value(forKey: "UserName") == "")
    }
}
