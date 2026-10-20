import Foundation

/// Schlüssel der Einstellungen in `UserDefaults` (Reiter „Allgemein“ seit M4, „Sicherheit“ seit M7); keine Zugangsdaten (S1).
enum AppSettings {
    /// PuTTY-Gewohnheit: Markierter Text landet sofort in der Zwischenablage.
    static let copyOnSelect: String = "KopierenBeimMarkieren"
    /// PuTTY-Gewohnheit: Rechtsklick fügt ein (nicht, solange ein Programm die Maus selbst auswertet).
    static let pasteOnRightClick: String = "EinfuegenPerRechtsklick"
    /// F1–F4 wie im Fork: Leeren, Alles kopieren, Duplizieren, Titel ändern – statt sie an den Server zu schicken.
    static let functionKeys: String = "FunktionstastenF1BisF4"
    /// Sicherheit (M7): Wünsche des Servers, Text in die Zwischenablage zu legen (OSC 52), ohne Rückfrage ablehnen.
    static let blockServerClipboard: String = "ZwischenablageVomServerAblehnen"
    /// Sicherheit (M7): Links aus dem Terminal (OSC 8, ⌘-Klick) nie öffnen.
    static let blockTerminalLinks: String = "LinksAusDemTerminalAblehnen"
    /// Sicherheit (M7): Links `ssh://`/`telnet://` aus anderen Apps nie öffnen (sonst immer mit Bestätigung, S6).
    static let blockAppLinks: String = "LinksAusAnderenAppsAblehnen"
}
