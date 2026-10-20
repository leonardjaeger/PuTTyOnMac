import TunnelTerminalCore

/// Beschriftungen der Profil-Auswahlen (Einstellungen, Editor).
extension TerminalProfile.ColorScheme {
    var title: String {
        switch self {
        case .automatic: "Automatisch (Hell/Dunkel)"
        case .light: "Hell"
        case .dark: "Dunkel"
        case .putty: "PuTTY"
        }
    }
}

extension TerminalProfile.CursorShape {
    var title: String {
        switch self {
        case .block: "Block"
        case .underline: "Unterstrich"
        case .bar: "Strich"
        }
    }
}

extension TerminalProfile.Bell {
    var title: String {
        switch self {
        case .sound: "Ton"
        case .visual: "Blinken"
        case .off: "Aus"
        }
    }
}
