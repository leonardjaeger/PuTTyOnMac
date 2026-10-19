import Testing
@testable import TunnelTerminalCore

/// Namen gespeicherter Sitzungen: Gruppe im Namen (docs/adr/0001), Prüfregeln S3, Dateinamen wie PuTTY.
@Suite("Sitzungsnamen")
struct SessionNameTests {
    @Test("Gültige Namen, auch mit Leerzeichen, Umlauten und Gruppe", arguments: [
        "Server", "Mein Server", "Heim/Server 2", "Büro/ä ö ü", "a.b-c_d@e+f", "Gruppe/Untergruppe/Titel"
    ])
    func acceptsNames(_ name: String) throws {
        try SessionName.check(name, reservedPrefix: "TunnelTerminal-Schnell-")
    }

    @Test("Abgelehnte Namen", arguments: [
        ("", InputError.empty(.sessionName)),
        ("-proxycmd x", .leadingDash(.sessionName)),
        (" Server", .whitespace(.sessionName)),
        ("Server ", .whitespace(.sessionName)),
        ("Gruppe/ Server", .whitespace(.sessionName)),
        ("a\nb", .controlCharacter(.sessionName)),
        ("a\u{202E}b", .controlCharacter(.sessionName)),
        ("/Server", .invalidCharacter(.sessionName)),
        ("Server/", .invalidCharacter(.sessionName)),
        ("a//b", .invalidCharacter(.sessionName)),
        ("Default Settings", .reservedName),
        ("default settings", .reservedName),
        (".", .leadingDot(.sessionName)),
        ("..", .leadingDot(.sessionName)),
        (".schreiben-x", .leadingDot(.sessionName)),             // Präfix der Zwischendateien, wird beim Start entfernt
        ("Gruppe/.versteckt", .leadingDot(.sessionName)),          // macOS-Dateisysteme unterscheiden Groß/klein meist nicht
        ("TunnelTerminal-Schnell-1", .reservedName),
        ("tunnelterminal-schnell-1", .reservedName)
    ])
    func rejectsNames(_ name: String, _ expected: InputError) {
        #expect(throws: expected) { try SessionName.check(name, reservedPrefix: "TunnelTerminal-Schnell-") }
    }

    @Test("Zu lange Namen werden abgelehnt, auch wenn erst der Dateiname zu lang wird (höchstens 255 Bytes)")
    func rejectsLongNames() {
        #expect(throws: InputError.tooLong(.sessionName)) {
            try SessionName.check(String(repeating: "ä", count: 50), reservedPrefix: "p-")   // 100 Bytes, Dateiname 300
        }
        #expect(throws: InputError.tooLong(.sessionName)) {
            try SessionName.check(String(repeating: "x", count: 201), reservedPrefix: "p-")
        }
    }

    @Test("Gruppe und Titel: vor und nach dem letzten „/“")
    func splitsGroup() throws {
        #expect(SessionName.group(of: "Heim/Server") == "Heim")
        #expect(SessionName.title(of: "Heim/Server") == "Server")
        #expect(SessionName.group(of: "a/b/c") == "a/b")
        #expect(SessionName.title(of: "a/b/c") == "c")
        #expect(SessionName.group(of: "Server") == nil)
        #expect(SessionName.title(of: "Server") == "Server")
        #expect(SessionName.make(group: "Heim", title: "Server") == "Heim/Server")
        #expect(SessionName.make(group: nil, title: "Server") == "Server")
        #expect(SessionName.make(group: "", title: "Server") == "Server")
    }

    @Test("Dateinamen zurückübersetzen: Umkehrung von SessionFile.fileName", arguments: [
        "Server", "Mein Server", "Heim/Server", "Büro/ä", "x%y:z", "Default Settings", "a+b-c.d@e_f"
    ])
    func decodesFileNames(_ name: String) {
        #expect(SessionName.decode(fileName: SessionFile.fileName(forSessionNamed: name)) == name)
    }

    @Test("Ungültige Dateinamen ergeben keinen Namen", arguments: ["%", "%4", "%ZZ", "%FF", "a%C3"])
    func rejectsBrokenFileNames(_ fileName: String) {
        #expect(SessionName.decode(fileName: fileName) == nil)
    }

    @Test("Freier Name: Nummer anhängen, Groß/klein zählt nicht")
    func findsFreeNames() {
        let taken: [String] = ["Neue Sitzung", "neue sitzung 2", "Heim/Box"]
        #expect(SessionName.available("Neue Sitzung", existing: taken) == "Neue Sitzung 3")
        #expect(SessionName.available("Heim/Box", existing: taken) == "Heim/Box 2")
        #expect(SessionName.available("Frei", existing: taken) == "Frei")
    }
}
