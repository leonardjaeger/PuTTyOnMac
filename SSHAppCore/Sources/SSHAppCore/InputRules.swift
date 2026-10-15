/// Feld, auf das sich eine Prüfregel bezieht (für verständliche Meldungen).
public enum InputField: String, Sendable {
    case host = "Server"
    case user = "Benutzername"
    case sessionName = "Sitzungsname"
    case key = "Schlüssel"
    case value = "Wert"
}

/// Abgelehnte Eingabe. Die Regeln stehen in Plan Abschnitt 6 (S3: keine Optionen einschleusen, S4: Sitzungsdateien).
public enum InputError: Error, Equatable, Sendable {
    case empty(InputField)
    case leadingDash(InputField)
    case controlCharacter(InputField)
    case whitespace(InputField)
    case invalidCharacter(InputField)
    case tooLong(InputField)
    case invalidPort
    case portRequired
    case invalidFile

    /// Meldung für die Oberfläche.
    public var message: String {
        switch self {
        case .empty(let field): "\(field.rawValue) fehlt."
        case .leadingDash(let field): "\(field.rawValue) darf nicht mit „-“ beginnen."
        case .controlCharacter(let field): "\(field.rawValue) enthält Steuerzeichen."
        case .whitespace(let field): "\(field.rawValue) darf keine Leerzeichen enthalten."
        case .invalidCharacter(let field): "\(field.rawValue) enthält unzulässige Zeichen."
        case .tooLong(let field): "\(field.rawValue) ist zu lang."
        case .invalidPort: "Der Port muss eine Zahl von 1 bis 65535 sein."
        case .portRequired: "Für dieses Protokoll ist ein Port nötig (z. B. server.example:7)."
        case .invalidFile: "Die Sitzungsdatei ist beschädigt."
        }
    }
}

/// Prüfregeln für alles, was über die Sitzungsdatei an plink geht.
enum InputRules {
    /// Allgemeine Regel für Namen (Server, Benutzer, Sitzung): nicht leer, kein führendes „-“,
    /// keine Steuer-, Format- oder Leerzeichen, begrenzte Länge.
    static func checkName(_ text: String, as field: InputField, maxLength: Int) throws(InputError) {
        guard !text.isEmpty else { throw .empty(field) }
        guard !text.hasPrefix("-") else { throw .leadingDash(field) }
        for scalar in text.unicodeScalars {
            if isControl(scalar) { throw .controlCharacter(field) }
            if scalar.properties.isWhitespace { throw .whitespace(field) }
        }
        guard text.utf8.count <= maxLength else { throw .tooLong(field) }
    }

    /// Server: Name aus ASCII-Buchstaben, Ziffern, „.“, „-“, „_“ oder eine IPv6-Adresse (ab zwei „:“).
    /// Ein einzelnes „:“ oder ein „@“ würde PuTTY selbst noch einmal aufteilen (docs/M1-Recherche.md 2.2).
    static func checkHost(_ host: String) throws(InputError) {
        try checkName(host, as: .host, maxLength: 253)
        let colons: Int = host.utf8.filter { $0 == UInt8(ascii: ":") }.count
        if colons == 0 {
            guard host.utf8.allSatisfy(isNameByte) else { throw .invalidCharacter(.host) }
            return
        }
        guard colons >= 2 else { throw .invalidCharacter(.host) }
        let parts: [Substring] = host.split(separator: "%", maxSplits: 1, omittingEmptySubsequences: false)
        let address: Substring = parts[0]
        guard address.utf8.allSatisfy(isAddressByte) else { throw .invalidCharacter(.host) }
        if parts.count == 2 {
            let zone: Substring = parts[1]
            guard !zone.isEmpty, zone.utf8.allSatisfy(isNameByte) else { throw .invalidCharacter(.host) }
        }
    }

    /// Wert einer Sitzungsdatei: PuTTY maskiert nichts, also dürfen CR, LF und NUL nie hinein (S4).
    static func checkFileValue(_ text: String, as field: InputField) throws(InputError) {
        for byte in text.utf8 where byte == 0x0A || byte == 0x0D || byte == 0x00 {
            throw .controlCharacter(field)
        }
    }

    /// Cc (C0, DEL, C1), Cf (u. a. Richtungsumkehr U+202E) sowie Zeilen- und Absatztrenner.
    private static func isControl(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .control, .format, .lineSeparator, .paragraphSeparator: true
        default: false
        }
    }

    private static func isNameByte(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "A")...UInt8(ascii: "Z"),
             UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "."), UInt8(ascii: "-"), UInt8(ascii: "_"):
            true
        default:
            false
        }
    }

    private static func isAddressByte(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "a")...UInt8(ascii: "f"), UInt8(ascii: "A")...UInt8(ascii: "F"),
             UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: ":"), UInt8(ascii: "."):
            true
        default:
            false
        }
    }
}
