import Foundation
import Testing
@testable import TunnelTerminalCore

/// Profile (Plan M4): Schrift, Größe, Farbschema, Rückblättern, Cursor, Glocke; je Sitzung wählbar.
@Suite("Profile")
struct TerminalProfileTests {
    @Test("Das Standardprofil hat eine feste Kennung und PuTTYs 2000 Zeilen Rückblättern")
    func standardProfile() {
        let standard: TerminalProfile = .standard
        #expect(standard.id == TerminalProfile.standardID)
        #expect(standard.name == "Standard")
        #expect(standard.fontName.isEmpty)   // Systemschrift (SF Mono)
        #expect(standard.fontSize == 13)
        #expect(standard.scrollbackLines == 2_000)
        #expect(standard.colorScheme == .automatic)
    }

    @Test("Liste: Standard zuerst, auch wenn es in den Daten fehlt oder weiter hinten steht")
    func listAlwaysStartsWithStandard() throws {
        var dark: TerminalProfile = .standard
        dark.id = UUID()
        dark.name = "Dunkel"
        dark.colorScheme = .dark
        let data: Data = try JSONEncoder().encode([dark, TerminalProfile.standard])
        let list: [TerminalProfile] = TerminalProfile.list(from: data)
        #expect(list.map(\.name) == ["Standard", "Dunkel"])
        #expect(TerminalProfile.list(from: nil).map(\.id) == [TerminalProfile.standardID])
        #expect(TerminalProfile.list(from: Data("kaputt".utf8)).map(\.id) == [TerminalProfile.standardID])
    }

    @Test("Werte aus den Einstellungen werden begrenzt, doppelte Kennungen und leere Namen verworfen")
    func listSanitizesValues() throws {
        let other: UUID = UUID()
        let json: String = """
        [{"id":"\(other.uuidString)","name":"Groß","fontName":"","fontSize":500,"colorScheme":"putty",
          "scrollbackLines":-4,"cursorShape":"bar","bell":"visual"},
         {"id":"\(other.uuidString)","name":"Doppelt","fontName":"","fontSize":12,"colorScheme":"dark",
          "scrollbackLines":10,"cursorShape":"block","bell":"off"},
         {"id":"\(UUID().uuidString)","name":"  ","fontName":"","fontSize":12,"colorScheme":"dark",
          "scrollbackLines":10,"cursorShape":"block","bell":"off"},
         {"id":"\(UUID().uuidString)","name":"Unbekannt","fontName":"","fontSize":12,"colorScheme":"lila",
          "scrollbackLines":10,"cursorShape":"block","bell":"off"}]
        """
        let list: [TerminalProfile] = TerminalProfile.list(from: Data(json.utf8))
        #expect(list.map(\.name) == ["Standard", "Groß"])
        #expect(list[1].fontSize == TerminalProfile.fontSizes.upperBound)
        #expect(list[1].scrollbackLines == 0)
        #expect(list[1].cursorShape == .bar)
    }

    @Test("Namen: nicht leer, ohne Steuerzeichen, höchstens 64 Zeichen", arguments: [
        ("Dunkel", true), ("", false), ("   ", false), ("a\nb", false), ("a\u{202E}b", false),
        (String(repeating: "x", count: 65), false), (String(repeating: "x", count: 64), true)
    ])
    func names(name: String, valid: Bool) {
        #expect(((try? TerminalProfile.checkName(name)) != nil) == valid)
    }

    /// Werte aus PuTTY 0.85, settings.c (`Colour0`–`Colour21`); Reihenfolge der Bunten dort: normal, hell im Wechsel.
    @Test("Farbschema „PuTTY“ hat PuTTYs Standardfarben")
    func puttyPalette() throws {
        let palette: TerminalPalette = try #require(TerminalProfile.ColorScheme.putty.palette)
        #expect(palette.foreground == RGB(187, 187, 187))
        #expect(palette.background == RGB(0, 0, 0))
        #expect(palette.cursor == RGB(0, 255, 0))
        #expect(palette.ansi == [
            RGB(0, 0, 0), RGB(187, 0, 0), RGB(0, 187, 0), RGB(187, 187, 0),
            RGB(0, 0, 187), RGB(187, 0, 187), RGB(0, 187, 187), RGB(187, 187, 187),
            RGB(85, 85, 85), RGB(255, 85, 85), RGB(85, 255, 85), RGB(255, 255, 85),
            RGB(85, 85, 255), RGB(255, 85, 255), RGB(85, 255, 255), RGB(255, 255, 255)
        ])
    }

    @Test("Feste Schemata haben 16 Farben und genug Kontrast zwischen Schrift und Hintergrund")
    func fixedPalettes() throws {
        #expect(TerminalProfile.ColorScheme.automatic.palette == nil)   // Systemfarben, Hell/Dunkel automatisch
        for scheme in TerminalProfile.ColorScheme.allCases {
            guard let palette = scheme.palette else { continue }
            #expect(palette.ansi.count == 16)
            #expect(palette.foreground.contrast(to: palette.background) >= 4.5, "\(scheme)")
        }
    }
}
