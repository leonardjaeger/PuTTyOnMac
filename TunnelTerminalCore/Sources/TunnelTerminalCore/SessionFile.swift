import Foundation

/// Eine PuTTY-Sitzungsdatei (`Schlüssel=Wert` je Zeile, Format wie `unix/storage.c`, docs/M1-Recherche.md 1.2–1.3).
///
/// Die Zeilen werden als Bytes gehalten: Unbekannte Schlüssel, Zeilen ohne „=“, CRLF und Nicht-UTF-8
/// bleiben beim Zurückschreiben byte-gleich. Geschrieben werden nur geprüfte Werte (S4).
public struct SessionFile: Equatable, Sendable {
    private var lines: [[UInt8]]
    private var endsWithNewline: Bool

    public init() {
        lines = []
        endsWithNewline = true
    }

    /// Liest eine vorhandene Datei. NUL-Bytes werden abgelehnt (PuTTY liest Zeilen als C-Zeichenketten).
    public init(contents: Data) throws(InputError) {
        let bytes: [UInt8] = [UInt8](contents)
        guard !bytes.contains(0) else { throw .invalidFile }
        var split: [[UInt8]] = bytes.split(separator: 0x0A, omittingEmptySubsequences: false).map { [UInt8]($0) }
        endsWithNewline = bytes.isEmpty || bytes.last == 0x0A
        if endsWithNewline { split.removeLast() }   // leerer Rest hinter dem letzten Zeilenende
        lines = split
    }

    /// Die Datei, wie sie auf die Platte kommt.
    public var contents: Data {
        var data: Data = Data()
        for (index, line) in lines.enumerated() {
            data.append(contentsOf: line)
            if index < lines.count - 1 || endsWithNewline { data.append(0x0A) }
        }
        return data
    }

    /// Wert wie PuTTY: erster Treffer, Schlüssel groß/klein-genau, Wert endet am ersten CR.
    public func value(forKey key: String) -> String? {
        guard let index = index(of: key) else { return nil }
        let line: [UInt8] = lines[index]
        let start: Int = key.utf8.count + 1
        let end: Int = line[start...].firstIndex(of: 0x0D) ?? line.endIndex
        return String(decoding: line[start..<end], as: UTF8.self)
    }

    /// Alle Einträge in Dateireihenfolge, je Schlüssel nur der erste (wie PuTTY liest). Zeilen ohne „=“ fehlen.
    public var entries: [(key: String, value: String)] {
        var seen: Set<String> = []
        var result: [(key: String, value: String)] = []
        for line in lines {
            guard let equals = line.firstIndex(of: UInt8(ascii: "=")) else { continue }
            let key: String = String(decoding: line[..<equals], as: UTF8.self)
            guard seen.insert(key).inserted else { continue }
            let rest: ArraySlice<UInt8> = line[(equals + 1)...]
            let end: Int = rest.firstIndex(of: 0x0D) ?? rest.endIndex
            result.append((key, String(decoding: rest[..<end], as: UTF8.self)))
        }
        return result
    }

    /// Setzt einen Wert (ersetzt den ersten Treffer, sonst angehängt). Lehnt CR, LF und NUL ab (S4).
    public mutating func setValue(_ value: String, forKey key: String) throws(InputError) {
        guard !key.isEmpty else { throw .empty(.key) }
        guard !key.contains("=") else { throw .invalidCharacter(.key) }
        try InputRules.checkFileValue(key, as: .key)
        try InputRules.checkFileValue(value, as: .value)
        let line: [UInt8] = Array(key.utf8) + [UInt8(ascii: "=")] + Array(value.utf8)
        if let index = index(of: key) {
            lines[index] = line
        } else {
            lines.append(line)
            endsWithNewline = true
        }
    }

    /// Entfernt alle Zeilen mit diesem Schlüssel (z. B. ein Klartext-Passwort beim Import, S1).
    public mutating func removeValue(forKey key: String) {
        let prefix: [UInt8] = Array(key.utf8) + [UInt8(ascii: "=")]
        lines.removeAll { $0.starts(with: prefix) }
    }

    /// Dateiname unter `sessions/` wie PuTTYs `make_session_filename`: nur `+ - . @ _` und ASCII-Buchstaben
    /// und -Ziffern bleiben, alles andere byteweise `%XX` (Großbuchstaben); leerer Name = „Default Settings“.
    public static func fileName(forSessionNamed name: String) -> String {
        let hex: [Character] = Array("0123456789ABCDEF")
        var result: String = ""
        for byte in (name.isEmpty ? "Default Settings" : name).utf8 {
            switch byte {
            case UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "A")...UInt8(ascii: "Z"),
                 UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "+"), UInt8(ascii: "-"),
                 UInt8(ascii: "."), UInt8(ascii: "@"), UInt8(ascii: "_"):
                result.append(Character(Unicode.Scalar(byte)))
            default:
                result.append("%")
                result.append(hex[Int(byte >> 4)])
                result.append(hex[Int(byte & 0x0F)])
            }
        }
        return result
    }

    /// Sitzung für eine Schnellverbindung. `PortNumber` steht immer drin, weil plink sonst Port 22 nimmt,
    /// auch bei Raw (docs/M1-Recherche.md 2.1).
    public static func quickConnect(to endpoint: Endpoint, using connectionProtocol: ConnectionProtocol)
        throws(InputError) -> SessionFile {
        guard let port = endpoint.port ?? connectionProtocol.defaultPort else { throw .portRequired }
        var file: SessionFile = SessionFile()
        try file.setValue("1", forKey: "Present")
        try file.setValue(endpoint.host, forKey: "HostName")
        try file.setValue(String(port), forKey: "PortNumber")
        try file.setValue(connectionProtocol.rawValue, forKey: "Protocol")
        try file.setValue(endpoint.user ?? "", forKey: "UserName")
        // plink 0.85 übernimmt $TERM nicht (M0, B11)
        try file.setValue("xterm-256color", forKey: "TerminalType")
        return file
    }

    private func index(of key: String) -> Int? {
        let prefix: [UInt8] = Array(key.utf8) + [UInt8(ascii: "=")]
        return lines.firstIndex { $0.starts(with: prefix) }
    }
}
