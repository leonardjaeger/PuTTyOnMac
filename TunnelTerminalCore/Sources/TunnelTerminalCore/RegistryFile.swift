import Foundation

/// Windows-Registrierungs-Export von PuTTY (`regedit /e`, Zweig `HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions`).
///
/// Vertrauensgrenze: Die Datei kommt von außen. Gelesen werden nur Abschnitte direkt unter `Sessions\`, nur Texte und
/// `dword`; alles andere wird mit Hinweis übersprungen. Werte gehen nur über `SessionFile.setValue` in die Sitzung (S4).
public enum RegistryFile {
    /// Größte Datei, die gelesen wird.
    public static let maximumSize: Int = 16 << 20

    private static let sessionsPath: String = #"HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\"#
    private static let headers: Set<String> = ["Windows Registry Editor Version 5.00", "REGEDIT4"]

    // MARK: Lesen

    /// Alle Sitzungen der Datei in Dateireihenfolge. Wirft `notAnExport`, wenn Kopfzeile oder Zeichensatz nicht passen.
    public static func sessions(from data: Data) throws(InputError) -> [ImportedSession] {
        guard data.count <= maximumSize, let text = decode(data) else { throw .notAnExport }
        let lines: [String] = logicalLines(of: text)
        guard let header = lines.first, headers.contains(header.trimmingCharacters(in: .whitespaces)) else {
            throw .notAnExport
        }
        var sessions: [ImportedSession] = []
        var indexByName: [String: Int] = [:]
        var current: Int?
        for line in lines.dropFirst() {
            let trimmed: String = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix(";") { continue }
            if trimmed.hasPrefix("[") {
                current = sessionName(inHeader: trimmed).map { name in
                    if let index = indexByName[name] { return index }
                    sessions.append(ImportedSession(name: name, file: SessionFile()))
                    indexByName[name] = sessions.count - 1
                    return sessions.count - 1
                }
                continue
            }
            guard let index = current else { continue }
            if let note = addValue(line: trimmed, to: &sessions[index].file) { sessions[index].notes.append(note) }
        }
        return sessions
    }

    /// regedit schreibt UTF-16LE mit BOM, REGEDIT4 Windows-1252; UTF-8 kommt bei bearbeiteten Dateien vor.
    private static func decode(_ data: Data) -> String? {
        let bytes: [UInt8] = [UInt8](data)
        if bytes.starts(with: [0xFF, 0xFE]) { return String(bytes: bytes.dropFirst(2), encoding: .utf16LittleEndian) }
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { return String(bytes: bytes.dropFirst(3), encoding: .utf8) }
        return String(bytes: bytes, encoding: .utf8) ?? String(bytes: bytes, encoding: .windowsCP1252)
    }

    /// Zeilen an LF getrennt (CR am Ende entfernt); Zeilen mit „\“ am Ende werden mit der nächsten verbunden (hex-Werte).
    private static func logicalLines(of text: String) -> [String] {
        var lines: [String] = []
        var line: String.UnicodeScalarView = String.UnicodeScalarView()
        var pending: String = ""
        func finish() {
            var scalars: String.UnicodeScalarView = line
            if scalars.last == "\r" { scalars.removeLast() }
            // An `pending` anhängen statt neu zusammensetzen: sonst wüchse der Aufwand quadratisch mit Fortsetzungszeilen
            pending.unicodeScalars.append(contentsOf: scalars)
            line = String.UnicodeScalarView()
            if pending.hasSuffix("\\") {
                pending.removeLast()
            } else {
                lines.append(pending)
                pending = ""
            }
        }
        for scalar in text.unicodeScalars {
            if scalar == "\n" { finish() } else { line.append(scalar) }
        }
        finish()
        if !pending.isEmpty { lines.append(pending) }
        return lines
    }

    /// Sitzungsname aus `[HKEY_CURRENT_USER\…\Sessions\<maskiert>]`; `nil` für alle anderen Abschnitte und Löschungen.
    private static func sessionName(inHeader header: String) -> String? {
        guard header.hasSuffix("]"), !header.hasPrefix("[-") else { return nil }
        let path: Substring = header.dropFirst().dropLast()
        guard let range = path.range(of: sessionsPath, options: [.anchored, .caseInsensitive]) else { return nil }
        let escaped: Substring = path[range.upperBound...]
        guard !escaped.isEmpty, !escaped.contains("\\") else { return nil }
        return unescape(escaped)
    }

    /// Umkehrung von PuTTYs `escape_registry_key`. Die Bytes sind UTF-8 oder (Windows-PuTTY) Windows-1252.
    private static func unescape(_ escaped: Substring) -> String? {
        var bytes: [UInt8] = []
        let input: [UInt8] = Array(escaped.utf8)
        var index: Int = 0
        while index < input.count {
            if input[index] == UInt8(ascii: "%"), index + 2 < input.count,
               let high = SessionName.hexValue(input[index + 1]), let low = SessionName.hexValue(input[index + 2]) {
                bytes.append(high << 4 | low)
                index += 3
            } else {
                bytes.append(input[index])
                index += 1
            }
        }
        return String(bytes: bytes, encoding: .utf8) ?? String(bytes: bytes, encoding: .windowsCP1252)
    }

    /// Übernimmt eine Wertzeile. Gibt einen Hinweis zurück, wenn sie übersprungen wurde.
    private static func addValue(line: String, to file: inout SessionFile) -> String? {
        if line.hasPrefix("@=") { return "Standardwert „@“ übersprungen." }
        guard line.hasPrefix("\""), let (key, rest) = quoted(line.dropFirst()) else {
            return "Unlesbare Zeile übersprungen."
        }
        guard rest.hasPrefix("=") else { return note(key, "unlesbar") }
        let value: Substring = rest.dropFirst()
        let text: String
        if value.hasPrefix("\"") {
            guard let (string, tail) = quoted(value.dropFirst()), tail.allSatisfy(\.isWhitespace) else {
                return note(key, "unlesbarer Text")
            }
            text = string
        } else if value.lowercased().hasPrefix("dword:") {
            let digits: Substring = value.dropFirst(6)
            guard (1...8).contains(digits.count), digits.unicodeScalars.allSatisfy({ $0.isASCII && $0.properties.isASCIIHexDigit }),
                  let number = UInt32(digits, radix: 16) else { return note(key, "ungültige Zahl") }
            text = String(Int32(bitPattern: number))
        } else {
            return note(key, "Datentyp wird nicht unterstützt")
        }
        do {
            try file.setValue(text, forKey: key)
        } catch {
            return note(key, "unzulässige Zeichen")
        }
        return nil
    }

    /// Text bis zum schließenden Anführungszeichen; `\x` steht für `x` (regedit maskiert nur `\` und `"`).
    private static func quoted(_ input: Substring) -> (String, Substring)? {
        var result: String = ""
        var index: Substring.Index = input.startIndex
        while index < input.endIndex {
            let character: Character = input[index]
            index = input.index(after: index)
            switch character {
            case "\"": return (result, input[index...])
            case "\\":
                guard index < input.endIndex else { return nil }
                result.append(input[index])
                index = input.index(after: index)
            default: result.append(character)
            }
        }
        return nil
    }

    private static func note(_ key: String, _ reason: String) -> String {
        let shown: String = key.count > 60 ? String(key.prefix(60)) + "…" : key
        return "„\(shown)“ übersprungen (\(reason))."
    }

    // MARK: Schreiben

    /// Export wie regedit: UTF-16LE mit BOM, CRLF. Zahlen-Einstellungen als `dword`, alles andere als Text.
    public static func data(for sessions: [(name: String, file: SessionFile)]) -> Data {
        var text: String = "Windows Registry Editor Version 5.00\r\n\r\n"
        for session in sessions {
            text += "[" + sessionsPath + escape(session.name) + "]\r\n"
            for (key, value) in session.file.entries {
                text += quote(key) + "=" + (dword(key: key, value: value) ?? quote(value)) + "\r\n"
            }
            text += "\r\n"
        }
        var data: Data = Data([0xFF, 0xFE])
        data.reserveCapacity(2 + text.utf16.count * 2)
        for unit in text.utf16 { data.append(contentsOf: [UInt8(unit & 0xFF), UInt8(unit >> 8)]) }
        return data
    }

    private static func dword(key: String, value: String) -> String? {
        guard PuTTYSettingKeys.integerKeys.contains(key), let number = Int32(value), String(number) == value else {
            return nil
        }
        let hex: String = String(UInt32(bitPattern: number), radix: 16)
        return "dword:" + String(repeating: "0", count: 8 - hex.count) + hex
    }

    private static func quote(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// Wie PuTTYs `escape_registry_key`. Die Bytes sind Windows-1252 wie bei Windows-PuTTY, wenn der Name darin
    /// darstellbar ist und die Bytes nicht zugleich gültiges UTF-8 wären; sonst UTF-8.
    private static func escape(_ name: String) -> String {
        var bytes: [UInt8] = Array(name.utf8)
        if let windows = name.data(using: .windowsCP1252),
           windows.allSatisfy({ $0 < 0x80 }) || String(data: windows, encoding: .utf8) == nil {
            bytes = [UInt8](windows)
        }
        let hex: [Character] = Array("0123456789ABCDEF")
        var result: String = ""
        for (offset, byte) in bytes.enumerated() {
            let special: Bool = byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\\") || byte == UInt8(ascii: "*")
                || byte == UInt8(ascii: "?") || byte == UInt8(ascii: "%") || byte < 0x20 || byte > 0x7E
                || (byte == UInt8(ascii: ".") && offset == 0)
            if special {
                result.append("%")
                result.append(hex[Int(byte >> 4)])
                result.append(hex[Int(byte & 0x0F)])
            } else {
                result.append(Character(Unicode.Scalar(byte)))
            }
        }
        return result
    }
}
