import Foundation

/// Einfügen mit Rückfrage (S10): Jeder Zeilenumbruch kann in einer Shell einen Befehl sofort ausführen.
public enum PasteCheck {
    /// Zeilen, die das Einfügen abschließen würde (0 = ohne Rückfrage einfügen). CRLF zählt einmal.
    public static func linesNeedingConfirmation(in text: String) -> Int {
        var count: Int = 0
        var previous: Unicode.Scalar?
        for scalar in text.unicodeScalars {
            if scalar == "\r" || (scalar == "\n" && previous != "\r") { count += 1 }
            previous = scalar
        }
        if count > 0, let last = text.unicodeScalars.last, last != "\n", last != "\r" { count += 1 }
        return count
    }
}

/// Links aus der Terminal-Ausgabe (OSC 8 und erkannte Adressen, S11): nur Web und E-Mail, nie Dateien, eigene
/// URL-Schemata anderer Apps oder `ssh://` (Links kann jeder Server ausgeben). Geöffnet wird erst nach Rückfrage.
public enum LinkPolicy {
    public static let allowedSchemes: Set<String> = ["http", "https", "mailto"]
    public static let maximumLength: Int = 2_048

    public static func openableURL(_ link: String) -> URL? {
        guard !link.isEmpty, link.utf8.count <= maximumLength,
              !link.unicodeScalars.contains(where: { InputRules.isControl($0) || $0.properties.isWhitespace }),
              let url = URL(string: link), let scheme = url.scheme?.lowercased(), allowedSchemes.contains(scheme)
        else { return nil }
        if scheme == "mailto" { return url.absoluteString.count > "mailto:".count ? url : nil }
        guard let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

/// Dateiname eines Sitzungsprotokolls, das die App selbst schreibt (plink protokolliert ohne Terminal nichts, M4).
public enum SessionLogName {
    public static func fileName(sessionName: String, date: Date, calendar: Calendar = .current) -> String {
        let parts: DateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        func two(_ value: Int?) -> String { String(format: "%02d", value ?? 0) }
        let stamp: String = "\(parts.year ?? 0)-\(two(parts.month))-\(two(parts.day)) "
            + "\(two(parts.hour))\(two(parts.minute))\(two(parts.second))"
        var name: String = String(sessionName.map { $0 == "/" || $0 == ":" ? "-" : $0 })
        if name.hasPrefix(".") { name = "_" + name.dropFirst() }
        // Dateinamen sind auf 255 Bytes begrenzt: Name kürzen, Datum und Endung bleiben
        let suffix: String = " \(stamp).log"
        while name.utf8.count + suffix.utf8.count > 255 { name.removeLast() }
        return name + suffix
    }
}
