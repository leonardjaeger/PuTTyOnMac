/// Adresse einer Verbindung: optional Benutzer, Server, optional Port.
public struct Endpoint: Equatable, Sendable {
    public let user: String?
    public let host: String
    public let port: Int?

    public init(user: String? = nil, host: String, port: Int? = nil) throws(InputError) {
        if let user { try InputRules.checkName(user, as: .user, maxLength: 256) }
        try InputRules.checkHost(host)
        if let port, !(1...65535).contains(port) { throw .invalidPort }
        self.user = user
        self.host = host
        self.port = port
    }

    /// Liest „benutzer@server:port“, „[IPv6]:port“ oder eine IPv6-Adresse ohne Port.
    /// Das letzte „@“ trennt den Benutzer ab (wie PuTTY, docs/M1-Recherche.md 2.2).
    public init(parsing text: String) throws(InputError) {
        // Nur am Rand: Leerraum und Zeilenumbruch (eingefügte Zeile); im Inneren bleiben sie verboten (S4)
        var rest: Substring = Substring(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !rest.isEmpty else { throw .empty(.host) }
        var user: String? = nil
        if let at = rest.lastIndex(of: "@") {
            user = String(rest[..<at])
            rest = rest[rest.index(after: at)...]
            if user!.isEmpty { throw .empty(.user) }
        }
        guard !rest.isEmpty else { throw .empty(.host) }

        let host: Substring
        var portText: Substring? = nil
        if rest.hasPrefix("[") {
            guard let close = rest.firstIndex(of: "]") else { throw .invalidCharacter(.host) }
            host = rest[rest.index(after: rest.startIndex)..<close]
            let after: Substring = rest[rest.index(after: close)...]
            if !after.isEmpty {
                guard after.hasPrefix(":") else { throw .invalidCharacter(.host) }
                portText = after.dropFirst()
            }
            guard host.contains(":") else { throw .invalidCharacter(.host) }
        } else if rest.filter({ $0 == ":" }).count == 1, let colon = rest.firstIndex(of: ":") {
            host = rest[..<colon]
            portText = rest[rest.index(after: colon)...]
        } else {
            host = rest   // ohne „:“ oder IPv6 ohne Klammern
        }
        try self.init(user: user, host: String(host), port: try Self.port(portText))
    }

    /// Anzeige für Fenstertitel: „benutzer@server:port“, IPv6 in Klammern.
    public var displayName: String {
        let shownHost: String = host.contains(":") ? "[\(host)]" : host
        let userPart: String = user.map { "\($0)@" } ?? ""
        let portPart: String = port.map { ":\($0)" } ?? ""
        return userPart + shownHost + portPart
    }

    /// Nur Ziffern, höchstens fünf; `nil` ohne Port (auch für `ConnectionLink`).
    static func port(_ text: Substring?) throws(InputError) -> Int? {
        guard let text else { return nil }
        let isDigits: Bool = text.utf8.allSatisfy { $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }
        guard !text.isEmpty, text.utf8.count <= 5, isDigits, let value = Int(text) else {   // Bereich prüft init
            throw .invalidPort
        }
        return value
    }
}
