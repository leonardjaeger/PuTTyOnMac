import Foundation

/// Darstellung eines Terminals (Plan M4): Schrift, Farben, Rückblättern, Cursor, Glocke. Sitzungen verweisen über
/// `SessionFile.profileID` darauf; ohne Verweis gilt `standard`. Die Liste liegt in den Einstellungen der App.
public struct TerminalProfile: Codable, Equatable, Hashable, Identifiable, Sendable {
    public enum ColorScheme: String, Codable, CaseIterable, Sendable {
        /// Systemfarben, wechseln mit Hell/Dunkel
        case automatic, light, dark, putty
    }

    public enum CursorShape: String, Codable, CaseIterable, Sendable {
        case block, underline, bar
    }

    public enum Bell: String, Codable, CaseIterable, Sendable {
        case sound, visual, off
    }

    public var id: UUID
    public var name: String
    /// PostScript-Name einer Festbreitenschrift; leer = Systemschrift (SF Mono).
    public var fontName: String
    public var fontSize: Double
    public var colorScheme: ColorScheme
    public var scrollbackLines: Int
    public var cursorShape: CursorShape
    public var bell: Bell

    public static let fontSizes: ClosedRange<Double> = 8...72
    public static let scrollbackRange: ClosedRange<Int> = 0...100_000
    public static let nameLimit: Int = 64

    public static let standardID: UUID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    /// PuTTYs Vorgabe für das Rückblättern ist 2000 Zeilen (settings.c, `ScrollbackLines`).
    public static let standard: TerminalProfile = TerminalProfile(
        id: standardID, name: "Standard", fontName: "", fontSize: 13, colorScheme: .automatic,
        scrollbackLines: 2_000, cursorShape: .block, bell: .sound)

    public init(id: UUID, name: String, fontName: String, fontSize: Double, colorScheme: ColorScheme,
                scrollbackLines: Int, cursorShape: CursorShape, bell: Bell) {
        self.id = id
        self.name = name
        self.fontName = fontName
        self.fontSize = fontSize
        self.colorScheme = colorScheme
        self.scrollbackLines = scrollbackLines
        self.cursorShape = cursorShape
        self.bell = bell
    }

    public static func checkName(_ name: String) throws(InputError) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { throw .empty(.profileName) }
        for scalar in name.unicodeScalars where InputRules.isControl(scalar) { throw .controlCharacter(.profileName) }
        guard name.count <= nameLimit else { throw .tooLong(.profileName) }
    }

    /// Werte im erlaubten Bereich (Einstellungen sind lokale Daten, aber Rechnen mit Unsinn soll nie abstürzen).
    public var clamped: TerminalProfile {
        var copy: TerminalProfile = self
        copy.fontSize = fontSize.isFinite ? min(max(fontSize, Self.fontSizes.lowerBound), Self.fontSizes.upperBound) : 13
        copy.scrollbackLines = min(max(scrollbackLines, Self.scrollbackRange.lowerBound), Self.scrollbackRange.upperBound)
        return copy
    }

    /// Liste aus den gespeicherten Daten: Standard zuerst (immer vorhanden), unlesbare Einträge, ungültige Namen und
    /// doppelte Kennungen fallen weg.
    public static func list(from data: Data?) -> [TerminalProfile] {
        let stored: [TerminalProfile] = data.flatMap { try? JSONDecoder().decode([Lenient].self, from: $0) }?
            .compactMap(\.profile) ?? []
        var seen: Set<UUID> = []
        var result: [TerminalProfile] = []
        for profile in stored where (try? checkName(profile.name)) != nil && seen.insert(profile.id).inserted {
            result.append(profile.clamped)
        }
        let standardIndex: Int? = result.firstIndex { $0.id == standardID }
        let first: TerminalProfile = standardIndex.map { result.remove(at: $0) } ?? standard
        return [first] + result
    }

    /// Ein Eintrag, der sich nicht lesen lässt (z. B. ein unbekanntes Farbschema), wird übersprungen statt die Liste
    /// zu verwerfen.
    private struct Lenient: Decodable {
        let profile: TerminalProfile?

        init(from decoder: any Decoder) throws {
            profile = try? TerminalProfile(from: decoder)
        }
    }
}

/// Farbe mit 8 Bit je Kanal.
public struct RGB: Equatable, Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Kontrastverhältnis nach WCAG 2 (1…21).
    public func contrast(to other: RGB) -> Double {
        let lighter: Double = max(luminance, other.luminance)
        let darker: Double = min(luminance, other.luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private var luminance: Double {
        func linear(_ channel: UInt8) -> Double {
            let value: Double = Double(channel) / 255
            return value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

/// Feste Farben eines Schemas: Schrift, Hintergrund, Cursor und die 16 ANSI-Farben (0–7 normal, 8–15 hell).
public struct TerminalPalette: Equatable, Sendable {
    public let foreground: RGB
    public let background: RGB
    public let cursor: RGB
    public let ansi: [RGB]
}

extension TerminalProfile.ColorScheme {
    /// `nil` für `automatic` (Systemfarben).
    public var palette: TerminalPalette? {
        switch self {
        case .automatic: nil
        case .light: TerminalPalette(foreground: RGB(0, 0, 0), background: RGB(255, 255, 255), cursor: RGB(0, 0, 0),
                                     ansi: Self.lightANSI)
        case .dark: TerminalPalette(foreground: RGB(229, 229, 229), background: RGB(30, 30, 30),
                                    cursor: RGB(229, 229, 229), ansi: Self.darkANSI)
        case .putty: TerminalPalette(foreground: RGB(187, 187, 187), background: RGB(0, 0, 0), cursor: RGB(0, 255, 0),
                                     ansi: Self.puttyANSI)
        }
    }

    /// PuTTY 0.85, settings.c: `Colour6`–`Colour21` stehen als Paare normal/hell; hier erst alle normalen, dann die hellen.
    private static let puttyANSI: [RGB] = [
        RGB(0, 0, 0), RGB(187, 0, 0), RGB(0, 187, 0), RGB(187, 187, 0),
        RGB(0, 0, 187), RGB(187, 0, 187), RGB(0, 187, 187), RGB(187, 187, 187),
        RGB(85, 85, 85), RGB(255, 85, 85), RGB(85, 255, 85), RGB(255, 255, 85),
        RGB(85, 85, 255), RGB(255, 85, 255), RGB(85, 255, 255), RGB(255, 255, 255)
    ]

    private static let darkANSI: [RGB] = [
        RGB(0, 0, 0), RGB(205, 49, 49), RGB(13, 188, 121), RGB(229, 229, 16),
        RGB(36, 114, 200), RGB(188, 63, 188), RGB(17, 168, 205), RGB(229, 229, 229),
        RGB(102, 102, 102), RGB(241, 76, 76), RGB(35, 209, 139), RGB(245, 245, 67),
        RGB(59, 142, 234), RGB(214, 112, 214), RGB(41, 184, 219), RGB(255, 255, 255)
    ]

    private static let lightANSI: [RGB] = [
        RGB(0, 0, 0), RGB(205, 49, 49), RGB(0, 135, 0), RGB(148, 120, 0),
        RGB(4, 81, 165), RGB(188, 5, 188), RGB(5, 132, 168), RGB(85, 85, 85),
        RGB(102, 102, 102), RGB(205, 49, 49), RGB(20, 160, 20), RGB(150, 140, 0),
        RGB(4, 81, 165), RGB(188, 5, 188), RGB(5, 152, 188), RGB(165, 165, 165)
    ]
}
