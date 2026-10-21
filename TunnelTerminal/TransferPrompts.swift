import AppKit
import SwiftUI
import TunnelTerminalCore

/// Rückfragen während einer Dateiübertragung (M6) als Sheets und Hinweise am Fenster. Tests setzen eigene Antworten ein.
struct TransferPrompts {
    /// Passwort für `benutzer@server` (nur für diese Übertragung, nie gespeichert, S1); `nil` = abgebrochen.
    var password: (_ target: String, _ rejected: Bool) async -> String?
    /// Gleichnamige Dateien im Zielordner ersetzen?
    var replace: (_ names: [String]) async -> Bool
    /// Die Sitzung startet beim Verbinden etwas auf diesem Mac oder schickt Text an einen Proxy (S4) – trotzdem übertragen?
    var dangers: (_ warnings: [SessionWarning], _ session: String) async -> Bool

    /// Sheets und Hinweise am Fenster des Tabs.
    static func window(_ window: @escaping () -> NSWindow?) -> TransferPrompts {
        TransferPrompts(
            password: { target, rejected in
                guard let window = window() else { return nil }
                return await sheet(on: window) { finish in TransferPasswordSheet(target: target, rejected: rejected, finish: finish) }
            },
            replace: { names in
                guard let window = window() else { return false }
                let alert: NSAlert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = names.count == 1
                    ? "„\(SessionWarning.visible(names[0]))“ gibt es im Zielordner schon."
                    : "\(names.count) Dateien gibt es im Zielordner schon."
                let list: String = names.prefix(10).map(SessionWarning.visible).joined(separator: "\n")
                alert.informativeText = "Ersetzen überschreibt sie auf dem Server:\n\n" + list + (names.count > 10 ? "\n…" : "")
                alert.addButton(withTitle: "Abbrechen")
                alert.addButton(withTitle: "Ersetzen").hasDestructiveAction = true
                return await alert.beginSheetModal(for: window) == .alertSecondButtonReturn
            },
            dangers: { warnings, session in
                guard let window = window() else { return false }
                let alert: NSAlert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "„\(SessionWarning.visible(session))“ tut beim Übertragen mehr als nur verbinden."
                alert.informativeText = warnings.map(\.message).joined(separator: "\n\n")
                    + "\n\nNur übertragen, wenn du das kennst und ihm vertraust."
                alert.addButton(withTitle: "Abbrechen")
                alert.addButton(withTitle: "Übertragen")
                return await alert.beginSheetModal(for: window) == .alertSecondButtonReturn
            })
    }

    /// SwiftUI-Inhalt als Sheet am Fenster, bis er `finish` aufruft (genau einmal: Knopf oder Esc).
    static func sheet<Result: Sendable, Content: View>(on window: NSWindow,
                                              _ content: (@escaping (Result?) -> Void) -> Content) async -> Result? {
        await withCheckedContinuation { continuation in
            var sheet: NSWindow?
            var finished: Bool = false
            let host: NSHostingController<Content> = NSHostingController(rootView: content { result in
                guard !finished else { return }
                finished = true
                if let sheet { window.endSheet(sheet) }
                continuation.resume(returning: result)
            })
            // eigenes Sheet-Fenster: Es soll dem Inhalt folgen (z. B. die Fehlerzeile); RL 3.4 Regel 19 betrifft SwiftUI in
            // Auto-Layout-Fenstern mit Split-View, hier sind die Standard-Grenzen gewollt
            host.sizingOptions = .standardBounds
            let sheetWindow: NSWindow = NSWindow(contentViewController: host)
            sheetWindow.setContentSize(host.view.fittingSize)
            sheet = sheetWindow
            window.beginSheet(sheetWindow)
        }
    }
}
