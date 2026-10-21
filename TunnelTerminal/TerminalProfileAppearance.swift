import AppKit
import SwiftTerm
import TunnelTerminalCore

/// Überträgt ein Profil (Plan M4) auf ein SwiftTerm-Terminal; auch während einer Verbindung (die neue Größe geht wie
/// beim Ändern der Fenstergröße an plink).
extension TerminalView {
    func apply(_ profile: TerminalProfile) {
        let size: CGFloat = CGFloat(profile.fontSize)
        font = (profile.fontName.isEmpty ? nil : NSFont(name: profile.fontName, size: size))
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        if let palette = profile.colorScheme.palette {
            nativeForegroundColor = palette.foreground.color
            nativeBackgroundColor = palette.background.color
            caretColor = palette.cursor.color
            installColors(palette.ansi.map(\.terminalColor))
        } else {
            configureNativeColors()   // Systemfarben, folgen Hell/Dunkel
            caretColor = .textColor
            installColors(Color.defaultInstalledColors)
        }
        changeScrollback(profile.scrollbackLines == 0 ? nil : profile.scrollbackLines)
        let cursor: CursorStyle = switch profile.cursorShape {
        case .block: .steadyBlock
        case .underline: .steadyUnderline
        case .bar: .steadyBar
        }
        setCursorStyle(cursor)
        bellStyle = switch profile.bell {
        case .sound: .sound
        case .visual: .visual
        case .off: .none
        }
    }
}

extension RGB {
    fileprivate var color: NSColor {
        NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }

    /// SwiftTerm rechnet mit 16 Bit je Kanal.
    fileprivate var terminalColor: SwiftTerm.Color {
        SwiftTerm.Color(red: UInt16(red) * 257, green: UInt16(green) * 257, blue: UInt16(blue) * 257)
    }
}
