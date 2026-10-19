import CryptoKit
import Foundation

/// Ein bekannter Hostschlüssel aus PuTTYs `sshhostkeys`: Zeile `typ@port:server wert` (`unix/storage.c`).
public struct KnownHostKey: Equatable, Sendable, Identifiable {
    /// PuTTY-Kennung des Schlüsseltyps (`cache_id`), z. B. `ssh-ed25519`, `ecdsa-sha2-nistp256`, `rsa2`.
    public let keyType: String
    public let port: Int
    /// Server genau wie in der Datei (PuTTY vergleicht ohne Groß/klein-Ausgleich).
    public let host: String
    /// Schlüssel in PuTTYs Textform (Koordinaten bzw. Exponent und Modulus in Hex).
    public let value: String

    /// Kopf der Zeile; plink speichert je Kopf genau einen Schlüssel.
    public var id: String { "\(keyType)@\(port):\(host)" }

    /// Fingerabdruck wie `ssh-keygen -l` und plinks Abfrage („SHA256:…“); `nil`, wenn der Wert nicht lesbar ist.
    public var fingerprint: String? {
        guard let blob = Self.publicKeyBlob(keyType: keyType, value: value) else { return nil }
        let digest: SHA256.Digest = SHA256.hash(data: blob)
        let base64: String = Data(digest).base64EncodedString()
        return "SHA256:" + base64.replacingOccurrences(of: "=", with: "")
    }

    /// Typ für die Anzeige („ED25519“, „ECDSA P-256“, „RSA 3072“).
    public var typeTitle: String {
        switch keyType {
        case "ssh-ed25519": return "ED25519"
        case "ssh-ed448": return "ED448"
        case "dss": return "DSA"
        case "rsa2":
            let parts: [Substring] = value.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count == 2, let modulus = Self.hexBytes(parts[1]) else { return "RSA" }
            return "RSA \(Self.bitLength(modulus))"
        default:
            if keyType.hasPrefix("ecdsa-sha2-nistp") { return "ECDSA P-" + keyType.dropFirst("ecdsa-sha2-nistp".count) }
            return keyType
        }
    }

    // MARK: - Öffentlicher Schlüssel im SSH-Format (RFC 4253 6.6, RFC 8709, RFC 5656)

    /// Aus PuTTYs Textform (`*_cache_str` in crypto/) den Schlüssel so zusammensetzen, wie der Server ihn schickt.
    /// Ed448 und DSA haben keinen gemessenen Vektor (docs/M3-Recherche.md 3) und bleiben ohne Fingerabdruck.
    private static func publicKeyBlob(keyType: String, value: String) -> Data? {
        let parts: [Substring] = value.split(separator: ",", omittingEmptySubsequences: false)
        switch keyType {
        case "ssh-ed25519":
            // Punkt = y als 32 Byte little-endian, oberstes Bit = Vorzeichen von x (RFC 8032 5.1.2)
            guard parts.count == 2, let x = hexBytes(parts[0]), let y = hexBytes(parts[1]),
                  var encoded = padded(y, to: 32) else { return nil }
            encoded.reverse()
            if (x.last ?? 0) & 1 == 1 { encoded[31] |= 0x80 }
            return sshString(Data(keyType.utf8)) + sshString(Data(encoded))
        case "ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp521":
            let curve: String = String(keyType.dropFirst("ecdsa-sha2-".count))
            let size: Int = [ "nistp256": 32, "nistp384": 48, "nistp521": 66 ][curve] ?? 0
            guard parts.count == 3, parts[0] == curve, let x = hexBytes(parts[1]), let y = hexBytes(parts[2]),
                  let fixedX = padded(x, to: size), let fixedY = padded(y, to: size) else { return nil }
            return sshString(Data(keyType.utf8)) + sshString(Data(curve.utf8)) + sshString(Data([0x04] + fixedX + fixedY))
        case "rsa2":
            guard parts.count == 2, let exponent = hexBytes(parts[0]), let modulus = hexBytes(parts[1]) else { return nil }
            return sshString(Data("ssh-rsa".utf8)) + mpint(exponent) + mpint(modulus)
        default:
            return nil
        }
    }

    /// Längster erlaubter Hex-Wert: 16 384 Bit (größer schreibt PuTTY nicht; schützt vor riesigen Zeilen).
    private static let maximumHexDigits: Int = 4_096

    /// „0x…“ zu Bytes, big-endian, ohne führende Null-Bytes; `nil` bei leerem, zu langem oder ungültigem Wert.
    private static func hexBytes(_ text: Substring) -> [UInt8]? {
        guard text.hasPrefix("0x") else { return nil }
        var digits: [UInt8] = Array(text.utf8.dropFirst(2))
        guard !digits.isEmpty, digits.count <= maximumHexDigits else { return nil }
        if digits.count % 2 == 1 { digits.insert(UInt8(ascii: "0"), at: 0) }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(digits.count / 2)
        var index: Int = 0
        while index < digits.count {
            guard let high = nibble(digits[index]), let low = nibble(digits[index + 1]) else { return nil }
            bytes.append((high << 4) | low)
            index += 2
        }
        return Array(bytes.drop { $0 == 0 })
    }

    private static func nibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): byte - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): byte - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): byte - UInt8(ascii: "A") + 10
        default: nil
        }
    }

    /// Mit führenden Nullen auf feste Länge; `nil`, wenn der Wert länger ist.
    private static func padded(_ bytes: [UInt8], to size: Int) -> [UInt8]? {
        guard bytes.count <= size else { return nil }
        return [UInt8](repeating: 0, count: size - bytes.count) + bytes
    }

    private static func sshString(_ data: Data) -> Data {
        let length: UInt32 = UInt32(data.count)
        return Data([UInt8(length >> 24), UInt8((length >> 16) & 0xFF), UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF)]) + data
    }

    /// Positive Ganzzahl: führendes Null-Byte, wenn das oberste Bit gesetzt ist.
    private static func mpint(_ bytes: [UInt8]) -> Data {
        sshString(Data((bytes.first ?? 0) & 0x80 != 0 ? [0] + bytes : bytes))
    }

    private static func bitLength(_ bytes: [UInt8]) -> Int {
        guard let first = bytes.first else { return 0 }
        return (bytes.count - 1) * 8 + (8 - first.leadingZeroBitCount)
    }
}

/// PuTTYs Datei `sshhostkeys` im PuTTY-Ordner. Zeilen werden als Bytes gehalten: Beim Entfernen bleiben alle
/// übrigen Zeilen (auch unlesbare) byte-gleich.
public struct KnownHostKeys: Sendable {
    private var lines: [[UInt8]]

    /// Obergrenze wie bei Sitzungsdateien (eine Zeile hat höchstens wenige KiB).
    public static let maximumSize: Int = 1 << 20

    public init(contents: Data) {
        var split: [[UInt8]] = [UInt8](contents).split(separator: 0x0A, omittingEmptySubsequences: false).map { [UInt8]($0) }
        if split.last?.isEmpty == true { split.removeLast() }
        lines = split
    }

    public var contents: Data {
        Data(lines.flatMap { $0 + [0x0A] })
    }

    /// Lesbare Einträge in Dateireihenfolge.
    public var entries: [KnownHostKey] { lines.compactMap(Self.entry) }

    /// Einträge für genau diesen Server und Port (Schreibweise wie in der Sitzung).
    public func entries(host: String, port: Int) -> [KnownHostKey] {
        entries.filter { $0.port == port && $0.host.utf8.elementsEqual(host.utf8) }   // byteweise wie plink
    }

    /// Entfernt die Zeilen mit diesen Köpfen (`KnownHostKey.id`).
    public mutating func remove(_ ids: Set<String>) {
        lines.removeAll { line in Self.entry(line).map { ids.contains($0.id) } ?? false }
    }

    private static func entry(_ line: [UInt8]) -> KnownHostKey? {
        guard let space = line.firstIndex(of: UInt8(ascii: " ")),
              let at = line[..<space].firstIndex(of: UInt8(ascii: "@")),
              let colon = line[at..<space].firstIndex(of: UInt8(ascii: ":")) else { return nil }
        let portText: ArraySlice<UInt8> = line[(at + 1)..<colon]
        guard !portText.isEmpty, portText.count <= 5, portText.allSatisfy({ (0x30...0x39).contains($0) }),
              let port = Int(String(decoding: portText, as: UTF8.self)), (1...65_535).contains(port),
              at > 0, colon + 1 < space else { return nil }
        let value: ArraySlice<UInt8> = line[(space + 1)...]
        let end: Int = value.firstIndex(of: 0x0D) ?? value.endIndex
        return KnownHostKey(keyType: String(decoding: line[..<at], as: UTF8.self), port: port,
                            host: String(decoding: line[(colon + 1)..<space], as: UTF8.self),
                            value: String(decoding: value[..<end], as: UTF8.self))
    }
}
