import AppKit
import TunnelTerminalCore

/// Wünsche des Servers aus der Terminalausgabe (S11): Text in die Zwischenablage legen (OSC 52) und Links öffnen
/// (OSC 8, ⌘-Klick). Immer mit Rückfrage am Fenster des Tabs, oder ganz abgelehnt, wenn das unter Einstellungen ›
/// Sicherheit so gewählt ist (M7). Aus dem Fenster-Controller herausgelöst (M7); je Tab eines.
final class ServerRequestPrompts {
    /// Größte Datenmenge, die ein Server per OSC 52 in die Zwischenablage legen darf (1 MiB).
    static let clipboardLimit: Int = 1 << 20

    private let defaults: UserDefaults
    /// OSC 52 einmal abgelehnt: weitere Wünsche dieser Verbindung ohne Rückfrage verwerfen (sonst sperrt ein Server
    /// den Tab mit endlosen Rückfragen, Prüfer-Befund 3 aus M4).
    private var clipboardRefused: Bool = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Neue Verbindung im Tab: wieder fragen.
    func reset() {
        clipboardRefused = false
    }

    /// Läuft schon eine Rückfrage, wird der Wunsch verworfen (ein Server kann ihn in Schleife schicken).
    func clipboardCopy(_ content: Data, in window: NSWindow?) {
        guard !defaults.bool(forKey: AppSettings.blockServerClipboard), let window, window.attachedSheet == nil,
              !clipboardRefused, content.count <= Self.clipboardLimit,
              let text = String(data: content, encoding: .utf8), !text.isEmpty else { return }
        let alert: NSAlert = NSAlert()
        alert.messageText = "Der Server möchte Text in die Zwischenablage legen."
        alert.informativeText = "\(text.count) Zeichen:\n\n" + AlertText.preview(text)
        alert.addButton(withTitle: "Nicht erlauben")
        alert.addButton(withTitle: "In die Zwischenablage")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertSecondButtonReturn else {
                self?.clipboardRefused = true
                return
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    /// Nur http, https und mailto, immer mit Rückfrage und voller Adresse; alles andere wird nur gemeldet.
    func openLink(_ link: String, in window: NSWindow?) {
        guard let window, window.attachedSheet == nil else { return }
        let alert: NSAlert = NSAlert()
        let blocked: Bool = defaults.bool(forKey: AppSettings.blockTerminalLinks)
        guard !blocked, let url = LinkPolicy.openableURL(link) else {
            alert.messageText = "Dieser Link wird nicht geöffnet."
            alert.informativeText = (blocked ? "Links aus dem Terminal sind unter Einstellungen › Sicherheit abgeschaltet:\n\n"
                : "Aus dem Terminal öffnet \(AppIdentity.name) nur Web- und E-Mail-Adressen (http, https, mailto):\n\n")
                + AlertText.preview(link)
            alert.beginSheetModal(for: window)
            return
        }
        alert.messageText = "Link aus dem Terminal öffnen?"
        // Ziel eigens nennen: in „https://bank.example@boese.test“ ist boese.test das Ziel (Prüfer-Befund 10 aus M4)
        let target: String = url.host.map { "Ziel: \(SessionWarning.visible($0))\n\n" } ?? ""
        alert.informativeText = target + SessionWarning.visible(url.absoluteString) + "\n\nDer Link kommt vom Server bzw. "
            + "aus der Ausgabe eines Programms."
        alert.addButton(withTitle: "Abbrechen")
        alert.addButton(withTitle: "Öffnen")
        alert.beginSheetModal(for: window) { response in
            if response == .alertSecondButtonReturn { NSWorkspace.shared.open(url) }
        }
    }
}
