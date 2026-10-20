import Foundation

/// Link `ssh://` oder `telnet://` aus einer anderen App, z. B. Safari (Plan M7, S6). Übernommen werden nur Benutzer,
/// Server und Port; ein Passwort, Verbindungsparameter (`;fingerprint=…`), Pfad, Abfrage oder Anker lehnt der Leser ab,
/// statt sie still zu verwerfen – wer einen Fingerabdruck mitschickt, soll nicht glauben, er werde geprüft.
/// Benutzer und Server gehen danach durch dieselben Regeln wie die Schnellverbindung (`Endpoint`, S3).
public struct ConnectionLink: Equatable, Sendable {
    public let connectionProtocol: ConnectionProtocol
    public let endpoint: Endpoint

    /// Längster angenommener Link in UTF-8-Bytes.
    static let maximumLength: Int = 2048

    public init(parsing text: String) throws(InputError) {
        guard text.utf8.count <= Self.maximumLength else { throw .tooLong(.link) }
        for scalar in text.unicodeScalars {
            if InputRules.isControl(scalar) { throw .controlCharacter(.link) }
            if scalar.properties.isWhitespace { throw .whitespace(.link) }
        }
        guard let separator = text.range(of: "://") else { throw .unsupportedLink }
        switch text[..<separator.lowerBound].lowercased() {
        case "ssh": connectionProtocol = .ssh
        case "telnet": connectionProtocol = .telnet
        default: throw .unsupportedLink
        }
        let rest: Substring = text[separator.upperBound...]
        let authorityEnd: String.Index = rest.firstIndex { "/?#".contains($0) } ?? rest.endIndex
        // Ein „/“ am Ende ist üblich (RFC 4248); alles Weitere wäre ein Pfad, eine Abfrage oder ein Anker
        let tail: Substring = rest[authorityEnd...]
        guard tail.isEmpty || tail == "/" else { throw .linkHasExtras }

        // userinfo kennt kein unmaskiertes „@“ (RFC 3986 3.2.1): mehr als eines ist kein gültiger Link
        let parts: [Substring] = rest[..<authorityEnd].split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { throw .invalidCharacter(.link) }
        var user: String? = nil
        if parts.count == 2 {
            let info: Substring = parts[0]
            guard !info.isEmpty else { throw .empty(.user) }
            guard let decoded = String(info).removingPercentEncoding else { throw .invalidCharacter(.user) }
            // Nach dem Dekodieren prüfen: auch „%3A“ (Passwort) und „%3B“ (Parameter) zählen. Ein kodiertes „@“ oder
            // „/“ ließe die angezeigte Adresse einen anderen Server vorspiegeln („root%40bank.example%2F@…“).
            if decoded.contains(":") { throw .linkHasPassword }
            if decoded.contains(";") { throw .linkHasExtras }
            if decoded.contains(where: { "@/".contains($0) }) { throw .invalidCharacter(.user) }
            user = decoded
        }
        let (hostText, portText): (Substring, Substring?) = try Self.split(parts[parts.count - 1])
        guard !hostText.isEmpty else { throw .empty(.host) }
        // IPv6-Zone als „%25“ (RFC 6874) wird zu „%“ wie in der Schnellverbindung
        guard let host = String(hostText).removingPercentEncoding else { throw .invalidCharacter(.host) }
        // Ein leerer Port bedeutet den Standardport (RFC 3986 3.2.3)
        endpoint = try Endpoint(user: user, host: host, port: try Endpoint.port(portText?.isEmpty == false ? portText : nil))
    }

    /// Normalisierte Adresse für die Bestätigung, z. B. „ssh://test@server.example:2222“.
    public var address: String {
        "\(connectionProtocol.rawValue)://\(endpoint.displayName)"
    }

    /// Server und Port: „[IPv6]:port“ oder „name:port“.
    private static func split(_ text: Substring) throws(InputError) -> (Substring, Substring?) {
        if text.hasPrefix("[") {
            guard let close = text.firstIndex(of: "]") else { throw .invalidCharacter(.host) }
            let host: Substring = text[text.index(after: text.startIndex)..<close]
            guard host.contains(":") else { throw .invalidCharacter(.host) }   // Klammern nur um IPv6-Adressen
            let after: Substring = text[text.index(after: close)...]
            guard !after.isEmpty else { return (host, nil) }
            guard after.hasPrefix(":") else { throw .invalidCharacter(.host) }
            return (host, after.dropFirst())
        }
        let pieces: [Substring] = text.split(separator: ":", omittingEmptySubsequences: false)
        guard pieces.count <= 2 else { throw .invalidCharacter(.host) }
        return (pieces[0], pieces.count == 2 ? pieces[1] : nil)
    }
}
