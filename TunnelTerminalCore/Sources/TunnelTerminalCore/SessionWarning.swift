/// Einstellung einer Sitzung, die mehr tut als verbinden (Plan S4). Die App zeigt sie vor dem Import und
/// fragt bei einem lokalen Proxy-Befehl vor jedem Verbinden nach.
public indirect enum SessionWarning: Equatable, Sendable {
    /// Startet vor der Verbindung ein Programm auf diesem Mac (PuTTY-Proxy „Local“).
    case localProxyCommand(String)
    /// Befehl, den der Server statt der Shell ausführt.
    case remoteCommand(String)
    /// Der Server kann die Schlüssel im ssh-agent dieses Macs benutzen.
    case agentForwarding
    case portForwardings(String)
    /// Sitzungsprotokoll an (`LogType` 1/2): Die App speichert die Ausgabe in ihrem Protokollordner (M4).
    case sessionLog
    /// SSH-Paketprotokoll von plink (`LogType` 3/4) in diese Datei – enthält alles Getippte (M4).
    case packetLog(String)
    /// Eigene GSSAPI-Bibliothek: andere PuTTY-Installationen laden sie (`dlopen`, unix/gss.c); das plink der App ist seit
    /// M3 ohne GSSAPI gebaut (docs/M3-Recherche.md 1) – deshalb nur ein Hinweis, keine Rückfrage mehr.
    case gssLibrary(String)
    /// SSH-Proxy (`ProxyMethod` 6–8): Ist `ProxyHost` der Name einer gespeicherten Sitzung, lädt PuTTY deren Einstellungen.
    case proxySession(String)
    /// Fest eingetragene Hostschlüssel: plink fragt bei einem passenden Schlüssel nicht mehr nach (S5 umgangen).
    case manualHostKeys
    /// Gefahr aus der Sitzung, die als SSH-Proxy geladen wird (nur in `requiringConfirmation`).
    case viaProxy(String, SessionWarning)

    /// Führt etwas auf diesem Mac aus: beim Import nicht vorausgewählt, vor jedem Verbinden eine Rückfrage.
    public var isDangerous: Bool {
        switch self {
        case .localProxyCommand: true
        case .viaProxy(_, let warning): warning.isDangerous
        default: false
        }
    }

    /// Beim Import nicht vorausgewählt: Gefährliches und alles, was eine Datei auf diesem Mac schreibt.
    public var blocksPreselection: Bool {
        switch self {
        case .sessionLog, .packetLog, .manualHostKeys: true
        default: isDangerous
        }
    }

    public var message: String {
        switch self {
        case .localProxyCommand(let command): "Startet vor dem Verbinden diesen Befehl auf diesem Mac: \(Self.visible(command))"
        case .remoteCommand(let command): "Führt auf dem Server diesen Befehl aus: \(Self.visible(command))"
        case .agentForwarding: "Agent-Weiterleitung: Der Server kann die Schlüssel aus dem ssh-agent dieses Macs benutzen."
        case .portForwardings(let rules): "Port-Weiterleitungen: \(Self.visible(rules))"
        case .sessionLog: "Sitzungsprotokoll an: Die App speichert die Ausgabe des Servers in ihrem Protokollordner."
        case .packetLog(let path): "plink schreibt ein SSH-Paketprotokoll mit allen Eingaben (auch in der Shell getippten "
            + "Passwörtern) nach: \(Self.visible(path)). Abschalten: Sitzungsprotokoll im Editor ein- und wieder ausschalten."
        case .gssLibrary(let path): "Nennt eine eigene GSSAPI-Bibliothek (\(Self.visible(path))). Diese App lädt sie nicht, andere PuTTY-Installationen schon."
        case .manualHostKeys: "Legt den Hostschlüssel des Servers fest; plink fragt dann nicht mehr nach."
        case .proxySession(let name): "Verbindet über den SSH-Proxy „\(Self.visible(name))“ (gespeicherte Sitzung oder Server)."
        case .viaProxy(let name, let warning): "Über die Proxy-Sitzung „\(Self.visible(name))“: \(warning.message)"
        }
    }
}

extension SessionWarning {
    /// Text für die Anzeige: Steuer-, Format- und Richtungszeichen (z. B. U+202E) erscheinen als `\\u{…}`,
    /// damit ein Befehl nicht harmloser aussieht, als er ist.
    public static func visible(_ text: String) -> String {
        var result: String = ""
        for scalar in text.unicodeScalars {
            if InputRules.isControl(scalar) {
                result += "\\u{" + String(scalar.value, radix: 16, uppercase: true) + "}"
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}

extension SessionWarning {
    /// Alles Gefährliche, das vor dem Verbinden bestätigt werden muss – auch aus Sitzungen, die PuTTY als SSH-Proxy lädt:
    /// `ProxyHost` als Name einer gespeicherten Sitzung, sonst die Standardeinstellungen (`do_defaults`, proxy/sshproxy.c).
    /// `load` liefert `nil`, wenn es die Sitzung nicht gibt, und wirft, wenn sie nicht lesbar ist (dann nicht verbinden).
    public static func requiringConfirmation(for file: SessionFile,
                                             load: (String) throws -> SessionFile?) throws -> [SessionWarning] {
        var visited: Set<String> = []
        return try dangers(in: file, load: load, visited: &visited)
    }

    private static func dangers(in file: SessionFile, load: (String) throws -> SessionFile?,
                                visited: inout Set<String>) throws -> [SessionWarning] {
        var result: [SessionWarning] = file.warnings.filter(\.isDangerous)
        guard let host = file.sshProxyHost else { return result }
        var name: String = host
        var proxy: SessionFile? = try load(host)
        if proxy == nil {
            name = SessionName.defaultSettings
            proxy = try load(name)
        }
        guard let proxy, visited.insert(SessionName.fileKey(name)).inserted else { return result }
        result += try dangers(in: proxy, load: load, visited: &visited).map { .viaProxy(name, $0) }
        return result
    }
}

extension SessionFile {
    /// Warnungen in fester Reihenfolge. Zahlen liest die App wie PuTTY (`atoi`), Werte wie `settings.c` in 0.85.
    public var warnings: [SessionWarning] {
        var result: [SessionWarning] = []
        if let command = localProxyCommand { result.append(.localProxyCommand(command)) }
        if let command = value(forKey: "RemoteCommand"), !command.isEmpty { result.append(.remoteCommand(command)) }
        if integer(forKey: "AgentFwd") ?? 0 != 0 { result.append(.agentForwarding) }
        if let rules = value(forKey: "PortForwardings"), !rules.isEmpty { result.append(.portForwardings(rules)) }
        switch integer(forKey: "LogType") ?? 0 {
        case 1, 2: result.append(.sessionLog)
        case 3, 4: result.append(.packetLog(value(forKey: "LogFileName") ?? "putty.log"))
        default: break
        }
        if let library = value(forKey: "GSSCustom"), !library.isEmpty { result.append(.gssLibrary(library)) }
        if let proxy = sshProxyHost { result.append(.proxySession(proxy)) }
        if let keys = value(forKey: "SSHManualHostKeys"), !keys.isEmpty { result.append(.manualHostKeys) }
        return result
    }

    /// `ProxyHost` bei einem SSH-Proxy (`ProxyMethod` 6–8, PROXY_SSH_TCPIP/EXEC/SUBSYSTEM); PuTTYs Standard ist „proxy“.
    var sshProxyHost: String? {
        guard let method = integer(forKey: "ProxyMethod"), (6...8).contains(method) else { return nil }
        return value(forKey: "ProxyHost") ?? "proxy"
    }

    /// `ProxyMethod` 5 (PROXY_CMD); fehlt der Wert oder liegt er außerhalb 0…8, gilt das alte `ProxyType` mit 4 (conf-enums.h).
    private var localProxyCommand: String? {
        let isLocal: Bool
        if let method = integer(forKey: "ProxyMethod"), (0...8).contains(method) {
            isLocal = method == 5
        } else {
            isLocal = integer(forKey: "ProxyType") == 4
        }
        guard isLocal else { return nil }
        return expandedProxyCommand(value(forKey: "ProxyTelnetCommand") ?? "connect %host %port\\n")   // PuTTYs Standardwert
    }

    /// Befehl so, wie plink ihn ausführt (utils/format_connection_setup_command.c): `\\`, `\%`, `\r`, `\n`, `\t`,
    /// `\xHH` und `%%`, `%host`, `%port`, `%user`, `%pass`, `%proxyhost`, `%proxyport` (ohne Groß/klein) eingesetzt.
    /// So kann nichts hinter Platzhaltern oder Escapes versteckt werden. Das Passwort erscheint nur als „••••“.
    func expandedProxyCommand(_ template: String) -> String {
        let fields: [(String, String)] = [
            ("proxyhost", value(forKey: "ProxyHost") ?? "proxy"), ("proxyport", String(integer(forKey: "ProxyPort") ?? 80)),
            ("host", hostName), ("port", String(portNumber)), ("user", value(forKey: "ProxyUsername") ?? ""),
            ("pass", (value(forKey: "ProxyPassword") ?? "").isEmpty ? "" : "••••")
        ]
        let input: [UInt8] = Array(template.utf8)
        var output: [UInt8] = []
        var index: Int = 0
        func hex(_ byte: UInt8) -> UInt8? { SessionName.hexValue(byte) }
        while index < input.count {
            let byte: UInt8 = input[index]
            guard (byte == UInt8(ascii: "\\") || byte == UInt8(ascii: "%")), index + 1 < input.count else {
                output.append(byte)
                index += 1
                continue
            }
            let next: UInt8 = input[index + 1]
            if byte == UInt8(ascii: "\\") {
                switch next {
                case UInt8(ascii: "\\"), UInt8(ascii: "%"): output.append(next); index += 2
                case UInt8(ascii: "r"): output.append(0x0D); index += 2
                case UInt8(ascii: "n"): output.append(0x0A); index += 2
                case UInt8(ascii: "t"): output.append(0x09); index += 2
                case UInt8(ascii: "x"), UInt8(ascii: "X"):
                    if index + 3 < input.count, let high = hex(input[index + 2]), let low = hex(input[index + 3]) {
                        output.append(high << 4 | low)
                        index += 4
                    } else {
                        output.append(byte)
                        index += 1
                    }
                default: output += [byte, next]; index += 2
                }
            } else if next == UInt8(ascii: "%") {
                output.append(next)
                index += 2
            } else if let (keyword, replacement) = fields.first(where: { keyword, _ in
                index + 1 + keyword.utf8.count <= input.count
                    && String(decoding: input[(index + 1)..<(index + 1 + keyword.utf8.count)], as: UTF8.self)
                        .lowercased() == keyword
            }) {
                output += Array(replacement.utf8)
                index += 1 + keyword.utf8.count
            } else {
                output.append(byte)
                index += 1
            }
        }
        return String(decoding: output, as: UTF8.self)
    }

    /// Zahl genau wie PuTTY (`atoi` = `(int)strtol(…, 10)` auf macOS): C-Leerraum (Leerzeichen, 0x09–0x0D),
    /// Vorzeichen, beliebig viele Ziffern, bei Überlauf gesättigt auf 64 Bit, dann auf 32 Bit gekürzt; der Rest zählt
    /// nicht. Muss exakt sein, sonst ließe sich die Warnung vor einem lokalen Befehl mit „00000000005“ umgehen.
    /// `nil`, wenn der Schlüssel fehlt.
    public func integer(forKey key: String) -> Int? {
        guard let text = value(forKey: key) else { return nil }
        var bytes: Substring.UTF8View = Substring(text).utf8
        while let first = bytes.first, first == 0x20 || (0x09...0x0D).contains(first) { bytes = bytes.dropFirst() }
        var negative: Bool = false
        if let first = bytes.first, first == UInt8(ascii: "-") || first == UInt8(ascii: "+") {
            negative = first == UInt8(ascii: "-")
            bytes = bytes.dropFirst()
        }
        var magnitude: UInt64 = 0
        var overflow: Bool = false
        for byte in bytes {
            guard (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) else { break }
            let (times, o1) = magnitude.multipliedReportingOverflow(by: 10)
            let (sum, o2) = times.addingReportingOverflow(UInt64(byte - UInt8(ascii: "0")))
            if o1 || o2 { overflow = true; break }
            magnitude = sum
        }
        // strtol: LONG_MAX bzw. LONG_MIN bei Überlauf
        let long: Int64
        if negative {
            long = overflow || magnitude > UInt64(Int64.max) + 1 ? Int64.min : Int64(truncatingIfNeeded: 0 &- magnitude)
        } else {
            long = overflow || magnitude > UInt64(Int64.max) ? Int64.max : Int64(magnitude)
        }
        return Int(Int32(truncatingIfNeeded: long))
    }
}
