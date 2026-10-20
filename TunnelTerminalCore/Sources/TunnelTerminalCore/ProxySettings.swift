/// Proxy-Arten im Editor (`ProxyMethod`, conf-enums.h); 7 und 8 (SSH exec/subsystem) gelten als `ssh`.
public enum ProxyKind: Int, Sendable, CaseIterable {
    case none = 0
    case socks4 = 1
    case socks5 = 2
    case http = 3
    case telnet = 4
    case localCommand = 5
    case ssh = 6

    public var title: String {
        switch self {
        case .none: "Kein Proxy"
        case .socks4: "SOCKS 4"
        case .socks5: "SOCKS 5"
        case .http: "HTTP"
        case .telnet: "Telnet"
        case .localCommand: "Lokaler Befehl"
        case .ssh: "SSH-Jump-Host"
        }
    }
}

/// Proxy und Jump-Host (Plan M5). Vorgaben wie conf.h: Server „proxy“, Port 80, Befehl „connect %host %port\n“.
extension SessionFile {
    /// Wie PuTTY: `ProxyMethod` 0…8, sonst das alte `ProxyType` (0 keiner, 1 HTTP, 2 SOCKS, 3 Telnet, 4 Befehl).
    public var proxyKind: ProxyKind {
        if let method = integer(forKey: "ProxyMethod"), (0...8).contains(method) {
            return ProxyKind(rawValue: min(method, 6)) ?? .none
        }
        let socks: ProxyKind = integer(forKey: "ProxySOCKSVersion") == 4 ? .socks4 : .socks5
        return [1: .http, 2: socks, 3: .telnet, 4: .localCommand][integer(forKey: "ProxyType") ?? 0] ?? .none
    }

    /// Weder `ProxyMethod` (0…8) noch `ProxyType` (0…4) gültig: plink läse dann einen nicht gesetzten Wert (settings.c,
    /// `confval` bleibt ohne Zuweisung) – die App verbindet nicht und speichert kein Passwort dafür.
    public var hasUndefinedProxy: Bool {
        if let method = integer(forKey: "ProxyMethod"), (0...8).contains(method) { return false }
        return !(0...4).contains(integer(forKey: "ProxyType") ?? 0)
    }

    public var proxyHost: String { value(forKey: "ProxyHost") ?? "proxy" }
    public var proxyPort: Int { integer(forKey: "ProxyPort") ?? 80 }
    public var proxyUsername: String { value(forKey: "ProxyUsername") ?? "" }
    /// Vorlage des lokalen Befehls bzw. Telnet-Proxys, wie gespeichert (Platzhalter noch nicht eingesetzt).
    public var proxyCommand: String { value(forKey: "ProxyTelnetCommand") ?? "connect %host %port\\n" }

    /// Für SOCKS, HTTP und Telnet fällt ein ProxyHost weg, der kein Server ist (z. B. der Name einer Jump-Sitzung).
    public mutating func setProxyKind(_ kind: ProxyKind) throws(InputError) {
        if [.socks4, .socks5, .http, .telnet].contains(kind), let host = value(forKey: "ProxyHost"),
           (try? InputRules.checkHost(host)) == nil {
            removeValue(forKey: "ProxyHost")
        }
        try setValue(String(kind.rawValue), forKey: "ProxyMethod")
    }

    /// Server eines SOCKS-, HTTP- oder Telnet-Proxys (Regeln wie für Server, S3).
    public mutating func setProxyHost(_ host: String) throws(InputError) {
        try InputRules.checkHost(host)
        try setValue(host, forKey: "ProxyHost")
    }

    public mutating func setProxyPort(_ port: Int) throws(InputError) {
        guard (1...65_535).contains(port) else { throw .invalidPort }
        try setValue(String(port), forKey: "ProxyPort")
    }

    public mutating func setProxyUsername(_ user: String) throws(InputError) {
        if !user.isEmpty { try InputRules.checkName(user, as: .user, maxLength: 256) }
        try setValue(user, forKey: "ProxyUsername")
    }

    /// Lokaler Befehl: Vor jedem Verbinden fragt die App mit dem ausgeschriebenen Befehl nach (S4).
    public mutating func setProxyCommand(_ command: String) throws(InputError) {
        try setValue(command, forKey: "ProxyTelnetCommand")
    }

    /// Jump-Host: PuTTY lädt die gespeicherte Sitzung mit diesem Namen als SSH-Proxy (proxy/sshproxy.c, M5 gemessen).
    public mutating func setJumpHost(sessionNamed name: String) throws(InputError) {
        try InputRules.checkSessionName(name)
        try setValue(String(ProxyKind.ssh.rawValue), forKey: "ProxyMethod")
        try setValue(name, forKey: "ProxyHost")
    }

    /// Proxy in Worten für Editor und Hinweise; `nil` ohne Proxy.
    public var proxyDescription: String? {
        let host: String = proxyHost
        return switch proxyKind {
        case .none: nil
        case .socks4: "SOCKS 4 über \(host)"
        case .socks5: "SOCKS 5 über \(host)"
        case .http: "HTTP über \(host)"
        case .telnet: "Telnet über \(host)"
        case .localCommand: "Lokaler Befehl auf diesem Mac"
        case .ssh: "SSH über „\(host)“"
        }
    }

    /// Schaltet den Proxy ab (auch das alte `ProxyType`), z. B. einen importierten lokalen Befehl.
    public mutating func disableProxy() {
        try? setValue("0", forKey: "ProxyMethod")
        if value(forKey: "ProxyType") != nil { try? setValue("0", forKey: "ProxyType") }
    }
}
