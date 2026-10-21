/// Feld, auf das sich eine Prüfregel bezieht (für verständliche Meldungen).
public enum InputField: String, Sendable {
    case host = "Server"
    case user = "Benutzername"
    case sessionName = "Sitzungsname"
    case key = "Schlüssel"
    case value = "Wert"
    case terminalType = "Terminaltyp"
    case keepalive = "Keepalive-Intervall"
    case comment = "Kommentar"
    case path = "Pfad"
    case profileName = "Profilname"
    case remotePath = "Pfad auf dem Server"
    case link = "Link"
}

/// Abgelehnte Eingabe. Die Regeln stehen in Plan Abschnitt 6 (S3: keine Optionen einschleusen, S4: Sitzungsdateien).
public enum InputError: Error, Equatable, Sendable {
    case empty(InputField)
    case leadingDash(InputField)
    case leadingDot(InputField)
    case controlCharacter(InputField)
    case whitespace(InputField)
    case invalidCharacter(InputField)
    case tooLong(InputField)
    case invalidPort
    case portRequired
    case invalidFile
    case reservedName
    case notAnExport
    case notAPuTTYFolder
    case outOfRange(InputField)
    case nameTaken
    case profileNameTaken
    case notAbsolute
    case proxyLoop
    case localSocket
    case forwardingTaken
    case notAFile
    case backslashInName
    case singleCharacterHost
    case unsupportedLink
    case linkHasPassword
    case linkHasExtras

    /// Meldung für die Oberfläche.
    public var message: String {
        switch self {
        case .empty(let field): "\(field.rawValue) fehlt."
        case .leadingDash(let field): "\(field.rawValue) darf nicht mit „-“ beginnen."
        case .leadingDot(let field): "\(field.rawValue) darf nicht mit „.“ beginnen."
        case .controlCharacter(let field): "\(field.rawValue) enthält Steuerzeichen."
        case .whitespace(let field): "\(field.rawValue) darf keine Leerzeichen enthalten."
        case .invalidCharacter(let field): "\(field.rawValue) enthält unzulässige Zeichen."
        case .tooLong(let field): "\(field.rawValue) ist zu lang."
        case .invalidPort: "Der Port muss eine Zahl von 1 bis 65535 sein."
        case .portRequired: "Für dieses Protokoll ist ein Port nötig (z. B. server.example:7)."
        case .invalidFile: "Die Sitzungsdatei ist beschädigt."
        case .reservedName: "Dieser Name ist reserviert (Standardeinstellungen bzw. Schnellverbindungen)."
        case .notAnExport: "Die Datei ist kein Registrierungs-Export oder zu groß."
        case .notAPuTTYFolder: "Der Ordner enthält keine PuTTY-Sitzungen (Unterordner „sessions“ fehlt)."
        case .nameTaken: "Eine Sitzung mit diesem Namen gibt es schon."
        case .profileNameTaken: "Ein Profil mit diesem Namen gibt es schon."
        case .outOfRange(let field): "\(field.rawValue) liegt außerhalb des erlaubten Bereichs."
        case .notAbsolute: "Der Pfad muss vollständig sein (mit „/“ am Anfang)."
        case .forwardingTaken: "Für diesen Port gibt es schon eine Weiterleitung."
        case .notAFile: "Der Pfad nennt keine Datei (z. B. /var/log/syslog)."
        case .backslashInName: "pscp lädt Dateien mit „\\“ im Namen unter einem anderen Namen hoch – bitte die Datei umbenennen."
        case .singleCharacterHost: "pscp hält einen Server mit nur einem Zeichen im Namen für ein Laufwerk – bitte in der Sitzung "
            + "den vollständigen Namen oder die Adresse eintragen."
        case .unsupportedLink: "Geöffnet werden nur Links, die mit ssh:// oder telnet:// beginnen."
        case .linkHasPassword: "Der Link enthält ein Passwort. Passwörter übernimmt die App nie aus Links."
        case .linkHasExtras: "Der Link enthält mehr als Benutzer, Server und Port (z. B. einen Pfad, Parameter oder Fingerabdruck)."
        case .proxyLoop: "Die SSH-Proxy-Sitzungen verweisen im Kreis aufeinander – plink würde endlos weiterverbinden."
        case .localSocket: "Proxy oder entfernte Weiterleitung zeigt auf einen Pfad auf diesem Mac (lokaler Socket) – "
            + "das verbindet die App nicht."
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

    /// Sitzungsname für `plink -load` (S3): wie `checkName`, aber Leerzeichen im Inneren erlaubt (die App startet plink
    /// mit einer Argumentliste, nie über eine Shell). Jedes „/“-Segment (Gruppe, docs/adr/0001) ist nicht leer und
    /// beginnt und endet nicht mit Leerraum.
    static func checkSessionName(_ name: String) throws(InputError) {
        guard !name.isEmpty else { throw .empty(.sessionName) }
        guard !name.hasPrefix("-") else { throw .leadingDash(.sessionName) }
        for scalar in name.unicodeScalars where isControl(scalar) { throw .controlCharacter(.sessionName) }
        for segment in name.split(separator: "/", omittingEmptySubsequences: false) {
            guard let first = segment.unicodeScalars.first, let last = segment.unicodeScalars.last else {
                throw .invalidCharacter(.sessionName)
            }
            if first.properties.isWhitespace || last.properties.isWhitespace { throw .whitespace(.sessionName) }
            // „.“, „..“ und versteckte Dateien (auch die Zwischendateien „.schreiben-…“) sind keine Sitzungen
            if first == "." { throw .leadingDot(.sessionName) }
        }
        guard name.utf8.count <= 200,
              SessionFile.fileName(forSessionNamed: name).utf8.count <= 255 else { throw .tooLong(.sessionName) }
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

    /// Datei für puttygen bzw. `PublicKeyFile`: absolut (beginnt nie mit „-“) und ohne Steuerzeichen.
    static func checkAbsolutePath(_ path: String) throws(InputError) {
        guard path.hasPrefix("/") else { throw .notAbsolute }
        for scalar in path.unicodeScalars where isControl(scalar) { throw .controlCharacter(.path) }
    }

    /// Wert einer Sitzungsdatei: PuTTY maskiert nichts, also dürfen CR, LF und NUL nie hinein (S4).
    static func checkFileValue(_ text: String, as field: InputField) throws(InputError) {
        for byte in text.utf8 where byte == 0x0A || byte == 0x0D || byte == 0x00 {
            throw .controlCharacter(field)
        }
    }

    /// Cc (C0, DEL, C1), Cf (u. a. Richtungsumkehr U+202E) sowie Zeilen- und Absatztrenner.
    static func isControl(_ scalar: Unicode.Scalar) -> Bool {
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
