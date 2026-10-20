import Foundation

/// Schlüssel der Einstellungen in `UserDefaults` (Reiter „Allgemein“, Plan M4); keine Zugangsdaten (S1).
enum AppSettings {
    /// PuTTY-Gewohnheit: Markierter Text landet sofort in der Zwischenablage.
    static let copyOnSelect: String = "KopierenBeimMarkieren"
    /// PuTTY-Gewohnheit: Rechtsklick fügt ein (nicht, solange ein Programm die Maus selbst auswertet).
    static let pasteOnRightClick: String = "EinfuegenPerRechtsklick"
    /// F1–F4 wie im Fork: Leeren, Alles kopieren, Duplizieren, Titel ändern – statt sie an den Server zu schicken.
    static let functionKeys: String = "FunktionstastenF1BisF4"
}
