import AppKit
import TunnelTerminalCore

/// Rückfrage zu Links `ssh://`/`telnet://` aus anderen Apps (Plan M7, S6): verbinden nur nach Bestätigung mit der
/// vollständigen Adresse; abgelehnte Links (ungültig oder unter Einstellungen › Sicherheit abgeschaltet) nur melden.
enum AppLinkPrompt {
    /// `connect` läuft nur nach „Verbinden“, `done` immer, sobald die Rückfrage zu ist (auch ohne Fenster).
    static func show(_ text: String, defaults: UserDefaults = .standard, in window: NSWindow?, done: @escaping () -> Void,
                     connect: @escaping (ConnectionLink) -> Void) {
        guard let window, window.attachedSheet == nil else {
            done()
            return
        }
        let alert: NSAlert = NSAlert()
        let refusal: String?
        var parsed: ConnectionLink? = nil
        if defaults.bool(forKey: AppSettings.blockAppLinks) {
            refusal = "Links aus anderen Apps sind unter Einstellungen › Sicherheit abgeschaltet."
        } else {
            do {
                parsed = try ConnectionLink(parsing: text)
                refusal = nil
            } catch {
                refusal = error.message
            }
        }
        guard let link = parsed, refusal == nil else {
            alert.messageText = "Dieser Link wird nicht geöffnet."
            // Ein Passwort aus dem Link nie anzeigen (RFC 3986 3.2.1, docs/M7-Recherche.md 2)
            alert.informativeText = (refusal ?? "") + (Self.containsPassword(text) ? "" : "\n\n" + AlertText.preview(text))
            alert.beginSheetModal(for: window) { _ in done() }
            return
        }
        alert.messageText = "Verbindung aus einem Link öffnen?"
        alert.informativeText = details(of: link)
            + "\n\nDer Link kommt aus einer anderen App, z. B. einem Browser. Verbinde nur, wenn du den Server kennst."
        alert.addButton(withTitle: "Abbrechen")   // Standardknopf: Return verbindet nicht
        alert.addButton(withTitle: "Verbinden")
        alert.beginSheetModal(for: window) { response in
            if response == .alertSecondButtonReturn { connect(link) }
            done()
        }
    }

    /// Server zuerst (wie „Ziel:“ bei Links aus dem Terminal), dann die Teile einzeln und die vollständige Adresse.
    static func details(of link: ConnectionLink) -> String {
        let endpoint: Endpoint = link.endpoint
        let port: String = endpoint.port.map(String.init) ?? link.connectionProtocol.defaultPort.map { "\($0) (Standard)" } ?? "–"
        let kind: String = switch link.connectionProtocol {
        case .telnet: "Telnet – unverschlüsselt, auch Passwörter gehen im Klartext übers Netz"
        case .ssh: "SSH – der Server sieht die öffentlichen Schlüssel aus deinem Agenten"
        default: link.connectionProtocol.title
        }
        return "Server: \(SessionWarning.visible(endpoint.host))\n"
            + "Port: \(port)\n"
            + "Benutzer: \(endpoint.user.map(SessionWarning.visible) ?? "wird beim Verbinden gefragt")\n"
            + "Verbindungsart: \(kind)\n\n"
            + "Link: \(SessionWarning.visible(link.address))"
    }

    /// Steht zwischen „://“ und dem „@“ ein „:“ (roh oder kodiert), enthält der Link ein Passwort.
    static func containsPassword(_ text: String) -> Bool {
        guard let start = text.range(of: "://")?.upperBound else { return false }
        let authority: Substring = text[start...].prefix { !"/?#".contains($0) }
        guard let at = authority.lastIndex(of: "@") else { return false }
        let info: String = String(authority[..<at])
        return info.contains(":") || info.lowercased().contains("%3a")
    }
}

private extension Error {
    var message: String { (self as? InputError)?.message ?? localizedDescription }
}
