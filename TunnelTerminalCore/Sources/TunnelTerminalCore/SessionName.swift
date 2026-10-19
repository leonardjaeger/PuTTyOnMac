/// Namen gespeicherter Sitzungen. Die Gruppe steht im Namen vor dem letzten „/“ (docs/adr/0001).
public enum SessionName {
    /// PuTTYs Vorlage für neue Sitzungen; in der Oberfläche „Standardeinstellungen“.
    public static let defaultSettings: String = "Default Settings"

    /// Prüft einen Namen für eine neue oder umbenannte Sitzung: Regeln für `plink -load` (S3) und keine
    /// reservierten Namen – die Standardeinstellungen und das Präfix der Schnellverbindungen, deren Sitzungen
    /// die App beim Start löscht.
    public static func check(_ name: String, reservedPrefix: String) throws(InputError) {
        try InputRules.checkSessionName(name)
        // Groß/klein zählt nicht: Auf macOS-Dateisystemen wären es dieselben Dateien.
        let folded: String = name.lowercased()
        if folded == defaultSettings.lowercased() || folded.hasPrefix(reservedPrefix.lowercased()) { throw .reservedName }
    }

    /// Vergleichsschlüssel: zwei Namen mit demselben Schlüssel landen in derselben Datei
    /// (die üblichen macOS-Dateisysteme unterscheiden Groß/klein nicht).
    public static func fileKey(_ name: String) -> String {
        SessionFile.fileName(forSessionNamed: name).lowercased()
    }

    /// `name`, falls frei, sonst mit „ 2“, „ 3“, … am Ende.
    public static func available(_ name: String, existing: [String]) -> String {
        available(name, taken: Set(existing.map(fileKey)))
    }

    static func available(_ name: String, taken: Set<String>) -> String {
        guard taken.contains(fileKey(name)) else { return name }
        var number: Int = 2
        while taken.contains(fileKey("\(name) \(number)")) { number += 1 }
        return "\(name) \(number)"
    }

    public static func group(of name: String) -> String? {
        name.lastIndex(of: "/").map { String(name[..<$0]) }
    }

    public static func title(of name: String) -> String {
        name.lastIndex(of: "/").map { String(name[name.index(after: $0)...]) } ?? name
    }

    /// Setzt Gruppe und Titel zusammen; eine leere Gruppe heißt „keine Gruppe“.
    public static func make(group: String?, title: String) -> String {
        guard let group, !group.isEmpty else { return title }
        return group + "/" + title
    }

    /// Umkehrung von `SessionFile.fileName(forSessionNamed:)`: `%XX` → Byte, Ergebnis muss UTF-8 sein.
    /// Unvollständige oder ungültige Folgen ergeben `nil` (die Datei lässt sich dann nicht mit `-load` öffnen).
    public static func decode(fileName: String) -> String? {
        var bytes: [UInt8] = []
        var iterator: String.UTF8View.Iterator = fileName.utf8.makeIterator()
        while let byte = iterator.next() {
            guard byte == UInt8(ascii: "%") else { bytes.append(byte); continue }
            guard let high = iterator.next().flatMap(hexValue), let low = iterator.next().flatMap(hexValue) else { return nil }
            bytes.append(high << 4 | low)
        }
        let name: String = String(decoding: bytes, as: UTF8.self)
        return Array(name.utf8) == bytes ? name : nil   // nur gültiges UTF-8 übersteht den Rundlauf
    }

    static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): byte - UInt8(ascii: "0")
        case UInt8(ascii: "A")...UInt8(ascii: "F"): byte - UInt8(ascii: "A") + 10
        case UInt8(ascii: "a")...UInt8(ascii: "f"): byte - UInt8(ascii: "a") + 10
        default: nil
        }
    }
}
