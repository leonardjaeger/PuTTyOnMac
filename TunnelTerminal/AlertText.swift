import TunnelTerminalCore

/// Texte aus fremder Quelle (Server, andere Apps) für Rückfragen und Meldungen.
enum AlertText {
    /// Kurze, sichtbare Vorschau: höchstens 10 Zeilen und 400 Zeichen, Steuerzeichen als `\u{…}`.
    static func preview(_ text: String) -> String {
        let all: [Substring] = text.split(separator: "\n", omittingEmptySubsequences: false)
        let shown: String = all.prefix(10).map { SessionWarning.visible(String($0)) }.joined(separator: "\n")
        let short: String = String(shown.prefix(400))
        return all.count > 10 || short.count < shown.count ? short + " …" : short
    }
}
