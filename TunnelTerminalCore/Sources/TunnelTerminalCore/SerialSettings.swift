/// Parität, wie plink 0.85 sie unter macOS umsetzt (unix/serial.c: Mark und Space wirken wie keine).
public enum SerialParity: Int, Sendable, CaseIterable {
    case none = 0
    case odd = 1
    case even = 2

    public var title: String {
        switch self {
        case .none: "Keine"
        case .odd: "Ungerade"
        case .even: "Gerade"
        }
    }
}

/// Flusskontrolle, wie plink 0.85 sie unter macOS umsetzt (DSR/DTR wirkt wie keine).
public enum SerialFlowControl: Int, Sendable, CaseIterable {
    case none = 0
    case xonXoff = 1
    case rtsCts = 2

    public var title: String {
        switch self {
        case .none: "Keine"
        case .xonXoff: "XON/XOFF"
        case .rtsCts: "RTS/CTS"
        }
    }
}

/// Serielle Verbindung (Plan M5). Vorgaben wie conf.h: 9600 Baud, 8 Datenbits, 1 Stoppbit, keine Parität, XON/XOFF.
extension SessionFile {
    public var serialLine: String { value(forKey: "SerialLine") ?? "" }
    /// Zweite Zeile in der Sitzungsliste (und Suche): Server, bei Seriell das Gerät.
    public var listAddress: String { connectionProtocol == .serial ? serialLine : hostName }
    public var serialSpeed: Int { integer(forKey: "SerialSpeed") ?? 9600 }
    public var serialDataBits: Int { integer(forKey: "SerialDataBits") ?? 8 }
    /// plink setzt 2 Stoppbits ab 4 Halbbits, sonst 1.
    public var serialStopBits: Int { (integer(forKey: "SerialStopHalfbits") ?? 2) >= 4 ? 2 : 1 }
    /// `nil` für Werte, die plink unter macOS nicht umsetzt (Mark, Space).
    public var serialParity: SerialParity? { SerialParity(rawValue: integer(forKey: "SerialParity") ?? 0) }
    /// `nil` für Werte, die plink unter macOS nicht umsetzt (DSR/DTR).
    public var serialFlowControl: SerialFlowControl? { SerialFlowControl(rawValue: integer(forKey: "SerialFlowControl") ?? 1) }

    /// Nur Geräte unter /dev (plink öffnet die Datei zum Lesen und Schreiben), ohne „..“ und Steuerzeichen.
    public mutating func setSerialLine(_ line: String) throws(InputError) {
        try InputRules.checkAbsolutePath(line)
        guard line.hasPrefix("/dev/"), line.count > 5,
              !line.split(separator: "/").contains("..") else { throw .invalidCharacter(.path) }
        try setValue(line, forKey: "SerialLine")
    }

    /// plink rundet auf den nächstkleineren Standardwert ab (B50 … B4000000).
    public mutating func setSerialSpeed(_ speed: Int) throws(InputError) {
        guard (50...4_000_000).contains(speed) else { throw .outOfRange(.value) }
        try setValue(String(speed), forKey: "SerialSpeed")
    }

    public mutating func setSerialDataBits(_ bits: Int) throws(InputError) {
        guard (5...8).contains(bits) else { throw .outOfRange(.value) }
        try setValue(String(bits), forKey: "SerialDataBits")
    }

    public mutating func setSerialStopBits(_ bits: Int) throws(InputError) {
        guard bits == 1 || bits == 2 else { throw .outOfRange(.value) }
        try setValue(String(bits * 2), forKey: "SerialStopHalfbits")
    }

    public mutating func setSerialParity(_ parity: SerialParity) {
        try? setValue(String(parity.rawValue), forKey: "SerialParity")
    }

    public mutating func setSerialFlowControl(_ flow: SerialFlowControl) {
        try? setValue(String(flow.rawValue), forKey: "SerialFlowControl")
    }
}
