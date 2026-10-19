import Foundation
import Testing
@testable import TunnelTerminalCore

/// Windows-PuTTY-Export (`regedit`, `HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions`) lesen und schreiben.
/// Testdaten nur mit Platzhaltern (S14).
@Suite("Registrierungsdatei")
struct RegistryFileTests {
    /// regedit schreibt UTF-16LE mit BOM und CRLF.
    private func utf16(_ text: String) -> Data {
        Data([0xFF, 0xFE]) + text.replacingOccurrences(of: "\n", with: "\r\n").data(using: .utf16LittleEndian)!
    }

    private let export: String = """
    Windows Registry Editor Version 5.00

    [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\Default%20Settings]
    "Present"=dword:00000001
    "HostName"=""

    ; Kommentar
    [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\Heim/Server%20A]
    "Present"=dword:00000001
    "HostName"="server.example"
    "PortNumber"=dword:00000016
    "Protocol"="ssh"
    "UserName"="test"
    "ShadowBoldOffset"=dword:ffffffff
    "RemoteCommand"="echo \\"hallo\\" C:\\\\pfad"
    "Font"="Courier New"

    [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\SshHostKeys]
    "ssh-ed25519@22:server.example"="0x1,0x2"

    """

    @Test("Liest Sitzungen aus einem UTF-16-Export: Namen, Zeichenketten, dword (auch negativ)")
    func parsesExport() throws {
        let sessions: [ImportedSession] = try RegistryFile.sessions(from: utf16(export))
        #expect(sessions.map(\.name) == ["Default Settings", "Heim/Server A"])
        let server: SessionFile = sessions[1].file
        #expect(server.value(forKey: "HostName") == "server.example")
        #expect(server.value(forKey: "PortNumber") == "22")
        #expect(server.value(forKey: "ShadowBoldOffset") == "-1")
        #expect(server.value(forKey: "RemoteCommand") == "echo \"hallo\" C:\\pfad")
        #expect(server.contents == Data("""
        Present=1
        HostName=server.example
        PortNumber=22
        Protocol=ssh
        UserName=test
        ShadowBoldOffset=-1
        RemoteCommand=echo "hallo" C:\\pfad
        Font=Courier New

        """.utf8))
        #expect(sessions.allSatisfy { $0.notes.isEmpty })
    }

    @Test("Liest auch REGEDIT4 (Windows-1252) und UTF-8 mit LF")
    func parsesOtherEncodings() throws {
        let text: String = "REGEDIT4\n\n[HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\B%FCro]\n\"UserName\"=\"Jos\u{E9}\"\n"
        let latin: [ImportedSession] = try RegistryFile.sessions(from: text.data(using: .windowsCP1252)!)
        #expect(latin.map(\.name) == ["Büro"])
        #expect(latin[0].file.value(forKey: "UserName") == "José")
        let utf8: [ImportedSession] = try RegistryFile.sessions(from: Data(text.utf8))
        #expect(utf8[0].file.value(forKey: "UserName") == "José")
    }

    @Test("Nicht unterstützte Werte werden übersprungen und vermerkt, die Sitzung bleibt")
    func skipsUnsupportedValues() throws {
        let text: String = """
        Windows Registry Editor Version 5.00

        [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\S]
        "HostName"="server.example"
        "Binaer"=hex:01,02,\\
          03,04
        "Pfad"=hex(2):25,00
        @="Standardwert"
        "Kaputt"=dword:zz
        "Gleich=Zeichen"="x"
        "Weiter"="ok"

        """
        let sessions: [ImportedSession] = try RegistryFile.sessions(from: utf16(text))
        #expect(sessions.count == 1)
        #expect(sessions[0].file.contents == Data("HostName=server.example\nWeiter=ok\n".utf8))
        #expect(sessions[0].notes.count == 5)   // hex, hex(2), Standardwert „@“, kaputtes dword, „=“ im Schlüssel
    }

    @Test("Gelöschte Schlüssel und fremde Bereiche werden ignoriert", arguments: [
        "[-HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\Weg]",
        "[HKEY_LOCAL_MACHINE\\Software\\SimonTatham\\PuTTY\\Sessions\\Fremd]",
        "[HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions]"
    ])
    func ignoresOtherSections(_ header: String) throws {
        let text: String = "Windows Registry Editor Version 5.00\n\n\(header)\n\"HostName\"=\"server.example\"\n"
        #expect(try RegistryFile.sessions(from: utf16(text)).isEmpty)
    }

    @Test("Keine Exportdatei oder zu groß: Fehler", arguments: [Data("HostName=x\n".utf8), Data()])
    func rejectsNonRegistryFiles(_ data: Data) {
        #expect(throws: InputError.notAnExport) { try RegistryFile.sessions(from: data) }
    }

    @Test("Zu große Datei wird abgelehnt")
    func rejectsHugeFiles() {
        var data: Data = Data("REGEDIT4\n".utf8)
        data.append(Data(count: RegistryFile.maximumSize))
        #expect(throws: InputError.notAnExport) { try RegistryFile.sessions(from: data) }
    }

    @Test("Export: UTF-16LE mit BOM und CRLF, Zahlen als dword, Namen maskiert wie Windows-PuTTY")
    func writesExport() throws {
        var file: SessionFile = SessionFile()
        try file.setValue("server.example", forKey: "HostName")
        try file.setValue("22", forKey: "PortNumber")
        try file.setValue("-1", forKey: "ShadowBoldOffset")
        try file.setValue("1234", forKey: "UserName")          // Zeichenkette, auch wenn sie wie eine Zahl aussieht
        try file.setValue("abc", forKey: "TermWidth")          // Zahlen-Schlüssel mit Text bleibt Zeichenkette
        try file.setValue("a\"b\\c", forKey: "RemoteCommand")
        let data: Data = RegistryFile.data(for: [(name: "Heim/.Server 1", file: file)])
        #expect(data.prefix(2) == Data([0xFF, 0xFE]))
        let text: String = String(data: data.dropFirst(2), encoding: .utf16LittleEndian)!
        #expect(text == """
        Windows Registry Editor Version 5.00\r
        \r
        [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\Heim/.Server%201]\r
        "HostName"="server.example"\r
        "PortNumber"=dword:00000016\r
        "ShadowBoldOffset"=dword:ffffffff\r
        "UserName"="1234"\r
        "TermWidth"="abc"\r
        "RemoteCommand"="a\\"b\\\\c"\r
        \r

        """)
        let leadingDot: String = String(data: RegistryFile.data(for: [(name: ".x", file: SessionFile())]).dropFirst(2),
                                        encoding: .utf16LittleEndian)!
        #expect(leadingDot.contains("Sessions\\%2Ex]"))
    }

    @Test("Rundlauf: Export und erneuter Import ergeben dieselben Sitzungen")
    func roundTrip() throws {
        var file: SessionFile = SessionFile()
        for (key, value) in [("Present", "1"), ("HostName", "server.example"), ("PortNumber", "2222"), ("Protocol", "ssh"),
                             ("UserName", "test"), ("Colour0", "187,187,187"), ("RemoteCommand", "ls \\ \"x\""),
                             ("Unbekannt", "ä ö ü"), ("ShadowBoldOffset", "-1")] {
            try file.setValue(value, forKey: key)
        }
        let names: [String] = ["Server", "Heim/Mein Server", "Büro/ä*?%", ".versteckt"]
        let sessions: [ImportedSession] = try RegistryFile.sessions(from: RegistryFile.data(for: names.map { ($0, file) }))
        #expect(sessions.map(\.name) == names)
        #expect(sessions.allSatisfy { $0.file == file && $0.notes.isEmpty })
    }

    @Test("Robustheit: zufällig veränderte Exporte bringen den Leser nie zum Absturz")
    func survivesMutations() {
        var generator: SeededGenerator = SeededGenerator(seed: 0x5EED)
        let base: [UInt8] = [UInt8](utf16(export))
        for _ in 0..<3000 {
            var bytes: [UInt8] = base
            for _ in 0..<Int.random(in: 1...8, using: &generator) {
                let index: Int = Int.random(in: 0..<bytes.count, using: &generator)
                switch Int.random(in: 0..<3, using: &generator) {
                case 0: bytes[index] = UInt8.random(in: 0...255, using: &generator)
                case 1: bytes.remove(at: index)
                default: bytes.insert(UInt8.random(in: 0...255, using: &generator), at: index)
                }
            }
            if let sessions = try? RegistryFile.sessions(from: Data(bytes)) {
                for session in sessions {
                    #expect(!session.file.contents.contains(0))
                }
            }
        }
    }
}

/// Reproduzierbarer Zufall für die Robustheitstests (SplitMix64).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z: UInt64 = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
