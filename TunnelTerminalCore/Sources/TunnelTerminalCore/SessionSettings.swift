import Foundation

/// Die Einstellungen, die der Sitzungs-Editor anbietet (Plan M2: nur häufig genutzte Felder).
/// Fehlende Werte gelten mit PuTTYs eingebauten Vorgaben (`settings.c`, `load_open_settings`).
/// Setzen ändert nur die betroffene Zeile; alle anderen bleiben byte-gleich.
extension SessionFile {
    /// Schalter im Editor mit ihrem PuTTY-Schlüssel.
    public enum Flag: String, CaseIterable, Sendable {
        case tcpKeepalives = "TCPKeepalives"
        case compression = "Compression"
        case agentForwarding = "AgentFwd"
        /// Lokale Weiterleitungen auch für andere Rechner im Netz öffnen (PuTTY-Standard: aus).
        case localPortAcceptAll = "LocalPortAcceptAll"
        /// Auch Ziele auf diesem Mac über den Proxy (PuTTY-Standard: aus, dann direkt; M5 gemessen).
        case proxyLocalhost = "ProxyLocalhost"
    }

    /// Schlüssel, die der Editor bearbeitet.
    public static let editedKeys: Set<String> = [
        "HostName", "PortNumber", "Protocol", "UserName", "TerminalType", "PingInterval", "PingIntervalSecs",
        "TCPKeepalives", "Compression", "AgentFwd", "RemoteCommand", "PublicKeyFile", profileKey, "LogType",
        "PortForwardings", "LocalPortAcceptAll", "ProxyMethod", "ProxyHost", "ProxyPort", "ProxyUsername",
        "ProxyTelnetCommand", "ProxyLocalhost", "SerialLine", "SerialSpeed", "SerialDataBits", "SerialStopHalfbits",
        "SerialParity", "SerialFlowControl"
    ]

    /// Eigener Schlüssel der App für das Profil (M4); PuTTY übergeht unbekannte Schlüssel.
    public static let profileKey: String = "TunnelTerminalProfile"

    /// Profil der Sitzung; `nil` ohne oder mit unlesbarem Eintrag (dann gilt das Standardprofil).
    public var profileID: UUID? { value(forKey: Self.profileKey).flatMap(UUID.init(uuidString:)) }

    /// `nil` entfernt den Eintrag (Standardprofil).
    public mutating func setProfileID(_ id: UUID?) throws(InputError) {
        if let id { try setValue(id.uuidString, forKey: Self.profileKey) } else { removeValue(forKey: Self.profileKey) }
    }

    /// Sitzungsprotokoll an: `LogType` 1 (druckbare) oder 2 (alle Ausgaben, putty.h). Die App schreibt es selbst – plink
    /// hat kein Terminal und protokolliert dabei nichts (Machbarkeit M4). 3 und 4 sind SSH-Paketprotokolle von plink.
    public var sessionLogEnabled: Bool { [1, 2].contains(integer(forKey: "LogType") ?? 0) }

    public mutating func setSessionLog(_ isOn: Bool) {
        try? setValue(isOn ? "2" : "0", forKey: "LogType")
    }

    public var hostName: String { value(forKey: "HostName") ?? "" }
    /// Port wie plink: `PortNumber` gilt nur, wenn `Protocol` ein Verfahren von plink nennt; sonst SSH auf 22
    /// (`settings.c`, `load_open_settings`; gemessen in M3).
    public var portNumber: Int {
        guard let name = value(forKey: "Protocol"), Self.plinkBackends.contains(name) else { return 22 }
        return integer(forKey: "PortNumber") ?? 22
    }

    /// Verfahren, die plink 0.85 kennt (`.id` der Backends in ssh/, otherbackends/, unix/serial.c).
    private static let plinkBackends: Set<String> = ["ssh", "ssh-connection", "telnet", "rlogin", "raw", "serial", "supdup"]
    public var userName: String { value(forKey: "UserName") ?? "" }
    public var terminalType: String { value(forKey: "TerminalType") ?? "xterm" }
    public var remoteCommand: String { value(forKey: "RemoteCommand") ?? "" }
    /// Schlüsseldatei für die Anmeldung (.ppk); leer: Agent bzw. Passwort.
    public var publicKeyFile: String { value(forKey: "PublicKeyFile") ?? "" }

    /// `nil` für Protokolle, die die App nicht anbietet (z. B. serial).
    public var connectionProtocol: ConnectionProtocol? { ConnectionProtocol(rawValue: value(forKey: "Protocol") ?? "ssh") }

    /// Keepalive-Intervall in Sekunden: PuTTY speichert Minuten und Sekunden getrennt.
    public var keepaliveSeconds: Int {
        (integer(forKey: "PingInterval") ?? 0) * 60 + (integer(forKey: "PingIntervalSecs") ?? 0)
    }

    public func isOn(_ flag: Flag) -> Bool { (integer(forKey: flag.rawValue) ?? 0) != 0 }
    public var tcpKeepalives: Bool { isOn(.tcpKeepalives) }
    public var compression: Bool { isOn(.compression) }
    public var agentForwarding: Bool { isOn(.agentForwarding) }

    /// Anzahl der Werte, die der Editor nicht zeigt und unverändert lässt.
    public var otherEntryCount: Int { entries.filter { !Self.editedKeys.contains($0.key) }.count }

    /// Leer ist erlaubt (wie in PuTTY); sonst gelten die Regeln der Schnellverbindung (S3).
    public mutating func setHostName(_ host: String) throws(InputError) {
        if !host.isEmpty { try InputRules.checkHost(host) }
        try setValue(host, forKey: "HostName")
    }

    public mutating func setUserName(_ user: String) throws(InputError) {
        if !user.isEmpty { try InputRules.checkName(user, as: .user, maxLength: 256) }
        try setValue(user, forKey: "UserName")
    }

    public mutating func setPortNumber(_ port: Int) throws(InputError) {
        guard (1...65_535).contains(port) else { throw .invalidPort }
        // ohne bekanntes Protocol ignorierte plink den Port; plink verbindet dann ohnehin per SSH
        if !Self.plinkBackends.contains(value(forKey: "Protocol") ?? "") { try setValue("ssh", forKey: "Protocol") }
        try setValue(String(port), forKey: "PortNumber")
    }

    public mutating func setConnectionProtocol(_ connectionProtocol: ConnectionProtocol) {
        try? setValue(connectionProtocol.rawValue, forKey: "Protocol")
    }

    public mutating func setTerminalType(_ type: String) throws(InputError) {
        try InputRules.checkName(type, as: .terminalType, maxLength: 64)
        try setValue(type, forKey: "TerminalType")
    }

    /// 0 schaltet Keepalives ab; höchstens ein Tag.
    public mutating func setKeepaliveSeconds(_ seconds: Int) throws(InputError) {
        guard (0...86_400).contains(seconds) else { throw .outOfRange(.keepalive) }
        try setValue(String(seconds / 60), forKey: "PingInterval")
        try setValue(String(seconds % 60), forKey: "PingIntervalSecs")
    }

    public mutating func setFlag(_ isOn: Bool, for flag: Flag) {
        try? setValue(isOn ? "1" : "0", forKey: flag.rawValue)
    }

    /// Leer schaltet die Schlüsseldatei ab; sonst ein absoluter Pfad.
    public mutating func setPublicKeyFile(_ path: String) throws(InputError) {
        if !path.isEmpty { try InputRules.checkAbsolutePath(path) }
        try setValue(path, forKey: "PublicKeyFile")
    }

    /// Ziel, an das ein gespeichertes Passwort gebunden ist (`benutzer@server:port`), oder `nil`, wenn die Sitzung
    /// kein Passwort aus dem Schlüsselbund bekommen darf (Grund in `passwordUnavailableReason`). Mit Proxy nie: plink
    /// setzte das Passwort sonst womöglich schon bei der Anmeldung am Proxy ein (M0 B12).
    /// Mit `SSHManualHostKeys` nie: plink nähme dann ohne Rückfrage jeden der dort genannten Schlüssel an (S5).
    public var passwordTarget: String? {
        guard passwordUnavailableReason == nil else { return nil }
        let address: (user: String, host: String) = plinkAddress
        return "\(address.user)@\(address.host):\(portNumber)"
    }

    public var passwordUnavailableReason: String? {
        let address: (user: String, host: String) = plinkAddress
        if connectionProtocol != .ssh { return "Passwörter speichert die App nur für SSH-Sitzungen." }
        if address.host.isEmpty { return "Zuerst einen Server eintragen." }
        if address.user.isEmpty { return "Zuerst einen Benutzernamen eintragen – das Passwort gilt nur für ihn." }
        if proxyDescription != nil || hasUndefinedProxy { return "Mit Proxy speichert die App kein Passwort." }
        if !(value(forKey: "SSHManualHostKeys") ?? "").isEmpty {
            return "Mit fest vorgegebenen Hostschlüsseln (SSHManualHostKeys) speichert die App kein Passwort."
        }
        return nil
    }

    /// Server und Port, unter denen plink die Hostschlüssel dieser SSH-Sitzung in `sshhostkeys` sucht und speichert
    /// (`ssh_hostport_setup`, ssh.c): `LogicalHostName` mit eigenem Port (sonst 22), wenn gesetzt; sonst der Server.
    public var hostKeyServer: (host: String, port: Int)? {
        guard connectionProtocol == .ssh else { return nil }
        let logical: [UInt8] = Array((value(forKey: "LogicalHostName") ?? "").utf8)
        if !logical.isEmpty {
            let colons: [Int] = Self.unbracketedColons(in: logical[...])
            guard colons.count == 1, let colon = colons.first else { return (Self.withoutBrackets(logical), 22) }
            let digits: ArraySlice<UInt8> = logical[(colon + 1)...].prefix { (0x30...0x39).contains($0) }
            let port: Int = logical.count > colon + 1 ? Int(String(decoding: digits, as: UTF8.self)) ?? 0 : 22
            return (Self.withoutBrackets(Array(logical[..<colon])), port)
        }
        let host: String = plinkAddress.host
        return host.isEmpty ? nil : (Self.withoutBrackets(Array(host.utf8)), portNumber)
    }

    /// Benutzer und Server, wie plink sie aus `HostName` liest (`prepare_session`, sessprep.c): Leerzeichen vorn
    /// fallen weg, ein `benutzer@` (bis zum letzten „@“) ersetzt `UserName`, ein einzelnes `:…` hinten wird
    /// verworfen, übrige Leerzeichen und Tabs zählen nicht. Byteweise, damit kein Unicode-Vergleich abweicht.
    private var plinkAddress: (user: String, host: String) {
        let blank: (UInt8) -> Bool = { $0 == 0x20 || $0 == 0x09 }
        var host: ArraySlice<UInt8> = Array(hostName.utf8).drop(while: blank)
        var user: String = userName
        if let at = host.lastIndex(of: 0x40) {
            user = String(decoding: host[..<at], as: UTF8.self)
            host = host[(at + 1)...]
        }
        let colons: [Int] = Self.unbracketedColons(in: host)
        if colons.count == 1, let colon = colons.first { host = host[..<colon] }
        return (user, String(decoding: host.filter { !blank($0) }, as: UTF8.self))
    }

    /// Stellen der „:“ außerhalb eckiger Klammern (`host_strchr_internal`).
    private static func unbracketedColons(in text: ArraySlice<UInt8>) -> [Int] {
        var depth: Int = 0
        var colons: [Int] = []
        for index in text.indices {
            switch text[index] {
            case 0x5B: depth += 1
            case 0x5D where depth > 0: depth -= 1
            case 0x3A where depth == 0: colons.append(index)
            default: break
            }
        }
        return colons
    }

    /// Eckige Klammern um ein IPv6-Literal weg, sonst unverändert (`host_strduptrim`).
    private static func withoutBrackets(_ host: [UInt8]) -> String {
        let isHex: (UInt8) -> Bool = { (0x30...0x39).contains($0) || (0x41...0x46).contains($0) || (0x61...0x66).contains($0) }
        guard host.first == 0x5B else { return String(decoding: host, as: UTF8.self) }
        var end: Int = 1
        var colons: Int = 0
        while end < host.count, host[end] != 0x5D, isHex(host[end]) || host[end] == 0x3A {
            if host[end] == 0x3A { colons += 1 }
            end += 1
        }
        if end < host.count, host[end] == 0x25 {   // „%“: Scope-ID bis zur „]“
            while end < host.count, host[end] != 0x5D { end += 1 }
        }
        guard end == host.count - 1, host[end] == 0x5D, colons > 1 else { return String(decoding: host, as: UTF8.self) }
        return String(decoding: host[1..<end], as: UTF8.self)
    }

    /// Darf leer sein; Zeilenumbrüche werden abgelehnt (S4).
    public mutating func setRemoteCommand(_ command: String) throws(InputError) {
        try setValue(command, forKey: "RemoteCommand")
    }
}
