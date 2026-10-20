import Foundation
import Testing
@testable import TunnelTerminalCore

/// Einfügen mit Rückfrage (S10) und Links aus der Ausgabe (S11).
@Suite("Einfügen und Links")
struct TerminalInputTests {
    @Test("Rückfrage bei jedem Zeilenumbruch, auch einem einzelnen am Ende", arguments: [
        ("ls -l", 0), ("ls -l\n", 1), ("a\nb", 2), ("a\r\nb\r\n", 2), ("a\rb", 2), ("\n\n", 2), ("", 0)
    ])
    func pasteLines(text: String, lines: Int) {
        #expect(PasteCheck.linesNeedingConfirmation(in: text) == lines)
    }

    @Test("Geöffnet werden nur http-, https- und mailto-Links", arguments: [
        ("https://server.example/pfad?x=1", true), ("HTTP://server.example", true), ("mailto:test@server.example", true),
        ("file:///etc/passwd", false), ("javascript:alert(1)", false), ("ssh://test@server.example", false),
        ("x-apple.systempreferences:com.apple.preference.security", false), ("https://", false),
        ("https://server.example/a b", false), ("https://server.example/\u{0}", false), ("", false),
        ("https://server.example/" + String(repeating: "a", count: 2_100), false), ("server.example", false)
    ])
    func links(link: String, allowed: Bool) {
        #expect((LinkPolicy.openableURL(link) != nil) == allowed)
    }

    @Test("Dateiname des Sitzungsprotokolls: Gruppe als Teil des Namens, Datum ohne Doppelpunkt")
    func logFileName() throws {
        var calendar: Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let date: Date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 19,
                                                                       hour: 16, minute: 7, second: 5)))
        #expect(SessionLogName.fileName(sessionName: "Server/Web 1", date: date, calendar: calendar)
                == "Server-Web 1 2026-10-19 160705.log")
        #expect(SessionLogName.fileName(sessionName: ".versteckt:x", date: date, calendar: calendar)
                == "_versteckt-x 2026-10-19 160705.log")
        let long: String = SessionLogName.fileName(sessionName: String(repeating: "ä", count: 200), date: date,
                                                   calendar: calendar)
        #expect(long.utf8.count <= 255)
        #expect(long.hasSuffix(" 2026-10-19 160705.log"))
    }
}
