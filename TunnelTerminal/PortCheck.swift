import Darwin

/// Ist ein lokaler Port schon belegt? plink meldet das nur mit `-v` und verbindet sonst still ohne die Weiterleitung
/// (docs/M5-Machbarkeit.md 1). Geprüft wird wie plink lauscht (unix/network.c): auf ::1 und 127.0.0.1 mit `SO_REUSEADDR`.
/// Mit „auch für andere Rechner“ oder eigener Bindadresse prüft die App nicht (`SessionFile.localListenPorts`).
enum PortCheck {
    static func isInUse(_ port: Int) -> Bool {
        guard (1...65_535).contains(port) else { return false }
        var v6: sockaddr_in6 = sockaddr_in6()
        v6.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        v6.sin6_family = sa_family_t(AF_INET6)
        v6.sin6_port = in_port_t(UInt16(port).bigEndian)
        v6.sin6_addr = in6addr_loopback
        var v4: sockaddr_in = sockaddr_in()
        v4.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        v4.sin_family = sa_family_t(AF_INET)
        v4.sin_port = in_port_t(UInt16(port).bigEndian)
        v4.sin_addr.s_addr = in_addr_t(UInt32(0x7F00_0001).bigEndian)
        return bindFails(&v6, family: AF_INET6) || bindFails(&v4, family: AF_INET)
    }

    private static func bindFails<Address>(_ address: inout Address, family: Int32) -> Bool {
        let socket: Int32 = Darwin.socket(family, SOCK_STREAM, 0)
        guard socket >= 0 else { return false }
        defer { close(socket) }
        var reuse: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        let result: Int32 = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(socket, $0, socklen_t(MemoryLayout<Address>.size)) }
        }
        return result != 0 && errno == EADDRINUSE
    }
}
