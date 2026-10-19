import Foundation
import Testing
@testable import TunnelTerminalCore

/// Importvorschau: Namen prüfen, Konflikte auflösen, Warnungen zeigen, Vorauswahl (Plan S4).
@Suite("Import")
struct SessionImportTests {
    private let prefix: String = "TunnelTerminal-Schnell-"

    private func session(_ name: String, _ lines: [String: String] = [:], notes: [String] = []) throws -> ImportedSession {
        var file: SessionFile = SessionFile()
        for (key, value) in lines.sorted(by: { $0.key < $1.key }) { try file.setValue(value, forKey: key) }
        return ImportedSession(name: name, file: file, notes: notes)
    }

    @Test("Namenskonflikte bekommen eine Nummer; Groß/klein zählt nicht (macOS-Dateisystem)")
    func resolvesConflicts() throws {
        let imported: [ImportedSession] = try ["Server", "server", "Heim/Box", "Neu"].map { try session($0) }
        let candidates: [ImportCandidate] = SessionImport.candidates(for: imported, existingNames: ["Server", "Heim/Box"],
                                                                      reservedPrefix: prefix)
        #expect(candidates.map(\.name) == ["Server 2", "server 3", "Heim/Box 2", "Neu"])
        #expect(candidates.map(\.originalName) == ["Server", "server", "Heim/Box", "Neu"])
        #expect(candidates.allSatisfy { $0.problem == nil && $0.isPreselected })
    }

    @Test("Ungültige und reservierte Namen werden nicht importiert")
    func rejectsInvalidNames() throws {
        let imported: [ImportedSession] = try ["-proxycmd x", "\(prefix)1", "a\u{202E}b", "/x"].map { try session($0) }
        let candidates: [ImportCandidate] = SessionImport.candidates(for: imported, existingNames: [], reservedPrefix: prefix)
        #expect(candidates.map(\.problem) == [.leadingDash(.sessionName), .reservedName, .controlCharacter(.sessionName),
                                              .invalidCharacter(.sessionName)])
        #expect(candidates.allSatisfy { !$0.isPreselected })
    }

    @Test("Zu lang nach dem Anhängen der Nummer: nicht importierbar")
    func rejectsTooLongAfterSuffix() throws {
        let name: String = String(repeating: "x", count: 200)
        let candidates: [ImportCandidate] = SessionImport.candidates(for: [try session(name)], existingNames: [name],
                                                                      reservedPrefix: prefix)
        #expect(candidates[0].problem == .tooLong(.sessionName))
    }

    @Test("Standardeinstellungen ersetzen die eigenen und sind nicht vorausgewählt")
    func defaultSettings() throws {
        let candidates: [ImportCandidate] = SessionImport.candidates(
            for: [try session("Default Settings")], existingNames: ["Default Settings"], reservedPrefix: prefix)
        #expect(candidates[0].name == "Default Settings")
        #expect(candidates[0].replacesDefaultSettings)
        #expect(candidates[0].problem == nil)
        #expect(!candidates[0].isPreselected)
    }

    @Test("Sitzungen mit lokalem Proxy-Befehl werden gewarnt und nicht vorausgewählt; Hinweise bleiben")
    func warnsAboutLocalCommands() throws {
        let imported: [ImportedSession] = [
            try session("Proxy", ["HostName": "server.example", "ProxyMethod": "5", "ProxyTelnetCommand": "nc %host %port"]),
            try session("Befehl", ["RemoteCommand": "uptime"], notes: ["„X“ übersprungen (Datentyp wird nicht unterstützt)."])
        ]
        let candidates: [ImportCandidate] = SessionImport.candidates(for: imported, existingNames: [], reservedPrefix: prefix)
        #expect(candidates[0].warnings == [.localProxyCommand("nc server.example 22")])
        #expect(!candidates[0].isPreselected)
        #expect(candidates[1].warnings == [.remoteCommand("uptime")])
        #expect(candidates[1].isPreselected)
        #expect(candidates[1].notes.count == 1)
    }

    @Test("Sitzungsprotokoll schreibt eine Datei auf diesem Mac: nicht vorausgewählt, aber importierbar")
    func sessionLogIsNotPreselected() throws {
        let candidates: [ImportCandidate] = SessionImport.candidates(
            for: [try session("Log", ["LogType": "1", "LogFileName": "/tmp/x.log"])], existingNames: [], reservedPrefix: prefix)
        #expect(candidates[0].problem == nil)
        #expect(!candidates[0].isPreselected)
    }

    @Test("Zu große Sitzungen werden nicht importiert (die App könnte sie danach nicht mehr lesen und prüfen)")
    func rejectsHugeSessions() throws {
        let huge: ImportedSession = try session("Gross", ["Fuellung": String(repeating: "x", count: PuTTYDirectory.maximumSessionSize)])
        let candidates: [ImportCandidate] = SessionImport.candidates(for: [huge], existingNames: [], reservedPrefix: prefix)
        #expect(candidates[0].problem == .invalidFile)
        #expect(!candidates[0].isPreselected)
    }

    @Test("Proxy über eine gespeicherte Sitzung wird angezeigt")
    func showsProxySession() throws {
        let candidates: [ImportCandidate] = SessionImport.candidates(
            for: [try session("A", ["ProxyMethod": "6", "ProxyHost": "B"])], existingNames: [], reservedPrefix: prefix)
        #expect(candidates[0].warnings == [.proxySession("B")])
    }

    @Test("Server und Benutzer werden wie im Editor geprüft (S3); leere Werte sind erlaubt", arguments: [
        (["HostName": "-oProxyCommand=x"], InputError.leadingDash(.host)),
        (["HostName": "x;curl|sh"], .invalidCharacter(.host)),
        (["UserName": "-l"], .leadingDash(.user)),
        (["UserName": "a b"], .whitespace(.user))
    ])
    func checksAddress(_ values: [String: String], _ expected: InputError) throws {
        let candidates: [ImportCandidate] = SessionImport.candidates(for: [try session("S", values)], existingNames: [],
                                                                      reservedPrefix: prefix)
        #expect(candidates[0].problem == expected)
        let empty: [ImportCandidate] = SessionImport.candidates(
            for: [try session("S", ["HostName": "", "UserName": ""])], existingNames: [], reservedPrefix: prefix)
        #expect(empty[0].problem == nil)
    }

    @Test("Proxy-Passwort wird nicht übernommen (Passwörter nur im Schlüsselbund, S1), mit Hinweis")
    func dropsProxyPassword() throws {
        let candidates: [ImportCandidate] = SessionImport.candidates(
            for: [try session("S", ["HostName": "server.example", "ProxyPassword": "geheim"])], existingNames: [],
            reservedPrefix: prefix)
        #expect(candidates[0].file.value(forKey: "ProxyPassword") == nil)
        #expect(candidates[0].file.value(forKey: "HostName") == "server.example")
        #expect(candidates[0].notes.contains { $0.contains("ProxyPassword") })
    }
}
