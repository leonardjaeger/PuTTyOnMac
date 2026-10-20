/// Eine Port-Weiterleitung einer SSH-Sitzung (Plan M5), so wie plink 0.85 `PortForwardings` liest
/// (settings.c `gppmap`, ssh/portfwd.c `portfwdmgr_config`; Format in docs/M5-Machbarkeit.md 1).
public struct PortForwarding: Equatable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case local = "L"
        case remote = "R"
        case dynamic = "D"

        public var title: String {
            switch self {
            case .local: "Lokal"
            case .remote: "Entfernt"
            case .dynamic: "Dynamisch"
            }
        }
    }

    public let kind: Kind
    /// „4“ oder „6“ für nur IPv4/IPv6; `nil` für beide (PuTTYs „A“ bzw. ohne Angabe).
    public let addressFamily: Character?
    /// Port, auf dem gelauscht wird, mit optionaler Bindadresse davor („8080“, „127.0.0.1:8080“).
    public let listen: String
    /// „ziel:port“; leer bei dynamischen Weiterleitungen.
    public let target: String

    /// Neue Weiterleitung aus dem Editor; das Ziel folgt den Regeln für Server (S3), IPv6 kommt in Klammern.
    public init(kind: Kind, port: Int, targetHost: String = "", targetPort: Int = 0) throws(InputError) {
        guard (1...65_535).contains(port) else { throw .invalidPort }
        self.kind = kind
        addressFamily = nil
        listen = String(port)
        if kind == .dynamic {
            target = ""
            return
        }
        try InputRules.checkHost(targetHost)
        guard (1...65_535).contains(targetPort) else { throw .invalidPort }
        target = (targetHost.contains(":") ? "[\(targetHost)]" : targetHost) + ":\(targetPort)"
    }

    private init(kind: Kind, addressFamily: Character?, listen: String, target: String) {
        self.kind = kind
        self.addressFamily = addressFamily
        self.listen = listen
        self.target = target
    }

    /// Port als Zahl (nach einer Bindadresse); `nil` bei Dienstnamen wie „smtp“ (plink schlägt sie nach).
    public var listenPort: Int? {
        let colons: [String.Index] = listen.indices.filter { listen[$0] == ":" }
        let digits: Substring = colons.last.map { listen[listen.index(after: $0)...] } ?? listen[...]
        guard let port = Int(digits), (1...65_535).contains(port) else { return nil }
        return port
    }

    /// Schlüssel, unter dem plink die Weiterleitung führt (lokal und dynamisch teilen sich „L“): gleicher Schlüssel =
    /// eine ersetzt die andere.
    public var storageKey: String {
        (addressFamily.map(String.init) ?? "") + (kind == .remote ? "R" : "L") + listen
    }

    /// Eine Bindadresse als Zahl, die nicht Loopback ist (z. B. „0.0.0.0:1080“): plink lauscht dann dort, also auch für
    /// andere Rechner – unabhängig von „LocalPortAcceptAll“ (unix/network.c `sk_newlistener`, AI_NUMERICHOST).
    public var listensBeyondLoopback: Bool {
        guard kind != .remote, let colon = listen.lastIndex(of: ":") else { return false }
        var address: Substring = listen[..<colon]
        if address.first == "[", address.last == "]" { address = address.dropFirst().dropLast() }
        let numericV4: Bool = !address.isEmpty && address.allSatisfy { $0.isASCII && ($0.isNumber || $0 == ".") }
        let numericV6: Bool = address.contains(":")
        guard numericV4 || numericV6 else { return false }   // Namen löst plink nicht auf: dann wie ohne Adresse
        return !(address.hasPrefix("127.") || address == "::1")
    }

    /// Kurzform für Inspektor und Editor (Werte über `SessionWarning.visible`, S4).
    public var title: String {
        let source: String = SessionWarning.visible(listen)
        return kind == .dynamic ? "\(source) (SOCKS-Proxy)" : "\(source) → \(SessionWarning.visible(target))"
    }

    // MARK: - Format von PuTTY

    /// Liest den Wert von `PortForwardings` wie plink: „,“ trennt, „\“ maskiert, ein „D“ im Schlüssel heißt dynamisch,
    /// derselbe Schlüssel ein zweites Mal ersetzt den ersten.
    static func list(from text: String) -> [PortForwarding] {
        var keys: [String] = []
        var values: [String: PortForwarding] = [:]
        for (key, value) in entries(in: text) {
            var normalized: String = key
            var target: String = value
            if let d = normalized.firstIndex(of: "D") {
                normalized.replaceSubrange(d...d, with: "L")
                target = "D"
            }
            var rest: Substring = normalized[...]
            var family: Character?
            if let first = rest.first, "A46".contains(first) {
                family = first == "A" ? nil : first
                rest = rest.dropFirst()
            }
            var kind: Kind = .local
            if rest.first == "L" || rest.first == "R" {
                kind = rest.first == "R" ? .remote : .local
                rest = rest.dropFirst()
            }
            if kind == .local && target == "D" {
                kind = .dynamic
                target = ""
            }
            let forwarding: PortForwarding = PortForwarding(kind: kind, addressFamily: family, listen: String(rest),
                                                            target: target)
            if values[normalized] == nil { keys.append(normalized) }
            values[normalized] = forwarding
        }
        return keys.compactMap { values[$0] }
    }

    /// Schreibt die Liste wie `wmap` (dynamisch als „D<port>“ mit leerem Wert).
    static func text(of list: [PortForwarding]) -> String {
        list.map { forwarding in
            let family: String = forwarding.addressFamily.map(String.init) ?? ""
            let key: String = family + forwarding.kind.rawValue + forwarding.listen
            return escaped(key) + "=" + escaped(forwarding.target)
        }.joined(separator: ",")
    }

    private static func escaped(_ text: String) -> String {
        var result: String = ""
        for character in text {
            if character == "=" || character == "," || character == "\\" { result.append("\\") }
            result.append(character)
        }
        return result
    }

    /// Schlüssel/Wert-Paare wie `gppmap`: Das erste unmaskierte „=“ trennt; ohne „=“ ist der Wert leer.
    private static func entries(in text: String) -> [(String, String)] {
        var result: [(String, String)] = []
        var key: String = ""
        var value: String = ""
        var inValue: Bool = false
        var escaping: Bool = false
        func finish() {
            if !key.isEmpty || inValue { result.append((key, value)) }
            key = ""; value = ""; inValue = false
        }
        for character in text {
            if escaping {
                escaping = false
                if inValue { value.append(character) } else { key.append(character) }
            } else if character == "\\" {
                escaping = true
            } else if character == "," {
                finish()
            } else if character == "=" {
                // wie gppmap: jedes unmaskierte „=“ beendet den Schlüssel bzw. beginnt den Wert neu (das letzte gilt)
                if inValue { value = "" } else { inValue = true }
            } else if inValue {
                value.append(character)
            } else {
                key.append(character)
            }
        }
        finish()
        return result
    }
}

extension SessionFile {
    /// Port-Weiterleitungen der Sitzung (nur bei SSH wirksam).
    public var portForwardings: [PortForwarding] { PortForwarding.list(from: value(forKey: "PortForwardings") ?? "") }

    public mutating func setPortForwardings(_ list: [PortForwarding]) throws(InputError) {
        try setValue(PortForwarding.text(of: list), forKey: "PortForwardings")
    }

    /// Lokale Ports (lokale und dynamische Weiterleitungen auf localhost), die vor dem Verbinden frei sein müssen: plink
    /// meldet einen belegten Port nur mit `-v` (docs/M5-Machbarkeit.md 1). Ohne Ports, wenn plink auch für andere Rechner
    /// lauscht – dort prüft die App nicht.
    public var localListenPorts: [Int] {
        guard !isOn(.localPortAcceptAll) else { return [] }
        return portForwardings.filter { $0.kind != .remote && !$0.listensBeyondLoopback }.compactMap(\.listenPort)
    }

    /// Lokale Weiterleitungen nehmen auch Verbindungen anderer Rechner an (Schalter oder eigene Bindadresse).
    var opensLocalPortsToNetwork: Bool {
        let local: [PortForwarding] = portForwardings.filter { $0.kind != .remote }
        return local.contains(where: \.listensBeyondLoopback) || (isOn(.localPortAcceptAll) && !local.isEmpty)
    }

    /// Ein „\\“ am Ende von `PortForwardings`: plinks Leser (`gppmap`) läse über das Ende des Werts hinaus.
    var hasDanglingEscapeInPortForwardings: Bool {
        guard let text = value(forKey: "PortForwardings") else { return false }
        return text.reversed().prefix { $0 == "\\" }.count % 2 == 1
    }

    /// Hängt eine neue Weiterleitung an; derselbe Port (lokal/dynamisch teilen sich die Ports) wird abgelehnt, sonst
    /// ersetzte plink die vorhandene still.
    public mutating func addPortForwarding(_ forwarding: PortForwarding) throws(InputError) {
        let list: [PortForwarding] = portForwardings
        guard !list.contains(where: { $0.storageKey == forwarding.storageKey }) else { throw .forwardingTaken }
        try setPortForwardings(list + [forwarding])
    }
}
