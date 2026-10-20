import AppKit
import SwiftTerm

/// SwiftTerm-Terminal mit den Bedienwünschen aus M4: Einfügen nur über die Rückfrage des Fensters (S10), PuTTY-Optionen
/// „Kopieren beim Markieren“ und „Rechtsklick fügt ein“, F1–F4 als Befehle (Optionen in `AppSettings`, aus im Standard).
final class AppTerminalView: TerminalView {
    /// Text aus der Zwischenablage soll eingefügt werden (Menü, ⌘V, Rechtsklick). Das Fenster prüft und fragt nach.
    var onPaste: ((String) -> Void)?
    /// Während die Hinweisleiste wartet: `true` = einfügen (⌘↩), `false` = abbrechen (Esc).
    var onPasteDecision: ((Bool) -> Void)?
    /// F1–F4 mit eingeschalteter Option; Wert 1…4.
    var onFunctionKey: ((Int) -> Void)?
    var isPastePending: Bool = false
    /// Nur für Tests ändern.
    var settings: UserDefaults = .standard

    private static let functionKeyCodes: [UInt16: Int] = [122: 1, 120: 2, 99: 3, 118: 4]
    private static let escapeKeyCode: UInt16 = 53
    private static let returnKeyCodes: Set<UInt16> = [36, 76]

    override func paste(_ sender: Any) {
        onPaste?(NSPasteboard.general.string(forType: .string) ?? "")
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if settings.bool(forKey: AppSettings.copyOnSelect), selectionActive { copy(self) }
    }

    /// Wertet ein Programm die Maus selbst aus (z. B. mc, vim mit `mouse=a`), bekommt es den Klick.
    override func rightMouseDown(with event: NSEvent) {
        if settings.bool(forKey: AppSettings.pasteOnRightClick), currentMouseMode == .off {
            paste(self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    /// Tasten vor SwiftTerm (über den Tasten-Monitor des Fensters; `keyDown` lässt sich außerhalb von SwiftTerm nicht
    /// überschreiben). `true`: verarbeitet, nicht an den Server.
    func handleKey(_ event: NSEvent) -> Bool {
        guard let window, event.window === window, window.firstResponder === self else { return false }
        let modifiers: NSEvent.ModifierFlags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if isPastePending {
            if event.keyCode == Self.escapeKeyCode {
                onPasteDecision?(false)
            } else if modifiers == .command && Self.returnKeyCodes.contains(event.keyCode) {
                onPasteDecision?(true)
            } else if modifiers.contains(.command) {
                return false   // Menübefehle (⌘W …) bleiben möglich
            } else {
                NSSound.beep()   // Tippen geht erst nach der Entscheidung weiter an den Server
            }
            return true
        }
        if modifiers.isEmpty, settings.bool(forKey: AppSettings.functionKeys),
           let number = Self.functionKeyCodes[event.keyCode] {
            onFunctionKey?(number)
            return true
        }
        return false
    }
}
