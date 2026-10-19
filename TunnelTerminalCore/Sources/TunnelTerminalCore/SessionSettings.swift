/// Die Einstellungen, die der Sitzungs-Editor anbietet (Plan M2: nur häufig genutzte Felder).
/// Fehlende Werte gelten mit PuTTYs eingebauten Vorgaben (`settings.c`, `load_open_settings`).
/// Setzen ändert nur die betroffene Zeile; alle anderen bleiben byte-gleich.
extension SessionFile {
    /// Schalter im Editor mit ihrem PuTTY-Schlüssel.
    public enum Flag: String, CaseIterable, Sendable {
        case tcpKeepalives = "TCPKeepalives"
        case compression = "Compression"
        case agentForwarding = "AgentFwd"
    }

    /// Schlüssel, die der Editor bearbeitet.
    public static let editedKeys: Set<String> = [
        "HostName", "PortNumber", "Protocol", "UserName", "TerminalType", "PingInterval", "PingIntervalSecs",
        "TCPKeepalives", "Compression", "AgentFwd", "RemoteCommand"
    ]

    public var hostName: String { value(forKey: "HostName") ?? "" }
    public var portNumber: Int { integer(forKey: "PortNumber") ?? 22 }
    public var userName: String { value(forKey: "UserName") ?? "" }
    public var terminalType: String { value(forKey: "TerminalType") ?? "xterm" }
    public var remoteCommand: String { value(forKey: "RemoteCommand") ?? "" }

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

    /// Darf leer sein; Zeilenumbrüche werden abgelehnt (S4).
    public mutating func setRemoteCommand(_ command: String) throws(InputError) {
        try setValue(command, forKey: "RemoteCommand")
    }

    /// Proxy in Worten für den Editor (`ProxyMethod`, conf-enums.h); `nil` ohne Proxy.
    public var proxyDescription: String? {
        let method: Int = integer(forKey: "ProxyMethod").flatMap { (0...8).contains($0) ? $0 : nil }
            ?? [0: 0, 1: 3, 2: 4, 3: 1, 4: 5][integer(forKey: "ProxyType") ?? 0] ?? 0   // altes ProxyType
        let host: String = value(forKey: "ProxyHost") ?? "proxy"
        switch method {
        case 1: return "SOCKS 4 über \(host)"
        case 2: return "SOCKS 5 über \(host)"
        case 3: return "HTTP über \(host)"
        case 4: return "Telnet über \(host)"
        case 5: return "Lokaler Befehl auf diesem Mac"
        case 6, 7, 8: return "SSH über „\(host)“"
        default: return nil
        }
    }

    /// Schaltet den Proxy ab (auch das alte `ProxyType`), z. B. einen importierten lokalen Befehl.
    public mutating func disableProxy() {
        try? setValue("0", forKey: "ProxyMethod")
        if value(forKey: "ProxyType") != nil { try? setValue("0", forKey: "ProxyType") }
    }
}
