import AppKit

/// Über-Fenster (Plan M7): das Standardfenster von macOS mit Name, Version und Copyright aus der Info.plist (einzige
/// persönliche Angabe: der Name des Autors, S14), dazu die Lizenzen. Die MIT-Lizenzen von TunnelTerminal, PuTTY und
/// SwiftTerm verlangen ihren Text in jeder Kopie – also auch in der App aus der DMG. Quelle sind `LICENSE` und
/// `THIRD_PARTY_NOTICES.md`, die als Ressourcen im App-Paket liegen (keine zweite Fassung im Code).
enum AboutPanel {
    static func show() {
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits()])
    }

    /// Nur dynamische Systemfarben, sonst wäre der Text im Dunkelmodus schwarz auf dunkel.
    static func credits(bundle: Bundle = .main) -> NSAttributedString {
        let result: NSMutableAttributedString = NSMutableAttributedString()
        let small: CGFloat = NSFont.smallSystemFontSize
        let heading: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: small), .foregroundColor: NSColor.labelColor]
        let body: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: small - 1),
                                                   .foregroundColor: NSColor.secondaryLabelColor]
        for (title, text) in licenseTexts(bundle: bundle) {
            if result.length > 0 { result.append(NSAttributedString(string: "\n\n", attributes: body)) }
            result.append(NSAttributedString(string: title + "\n", attributes: heading))
            result.append(NSAttributedString(string: text, attributes: body))
        }
        return result
    }

    /// Lizenz der App und Hinweise zu Fremdsoftware als lesbarer Text (Markdown-Zeichen für Überschriften und
    /// Codeblöcke entfernt). Fehlt eine Datei im Paket, bleibt der Abschnitt weg.
    private static func licenseTexts(bundle: Bundle) -> [(title: String, text: String)] {
        var sections: [(title: String, text: String)] = []
        if let url = bundle.url(forResource: "LICENSE", withExtension: nil),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            sections.append(("\(AppIdentity.name)", text.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        if let url = bundle.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            let lines: [Substring] = text.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.hasPrefix("```") && !$0.hasPrefix("# ") }
            let plain: String = lines.map { $0.hasPrefix("## ") ? String($0.dropFirst(3)) : String($0) }.joined(separator: "\n")
            sections.append(("Software Dritter", plain.replacing("`", with: "").trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return sections
    }
}
