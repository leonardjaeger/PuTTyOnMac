import Testing
@testable import TunnelTerminalCore

/// Schnellverbindung: „benutzer@host:port“ (Plan M1, S3).
@Suite("Adresse lesen")
struct EndpointTests {
    @Test("Nur Server")
    func hostOnly() throws {
        let endpoint: Endpoint = try Endpoint(parsing: "server.example")
        #expect(endpoint == (try Endpoint(host: "server.example")))
        #expect(endpoint.user == nil)
        #expect(endpoint.port == nil)
    }

    @Test("Benutzer, Server und Port")
    func userHostPort() throws {
        let endpoint: Endpoint = try Endpoint(parsing: "test@server.example:2222")
        #expect(endpoint.user == "test")
        #expect(endpoint.host == "server.example")
        #expect(endpoint.port == 2222)
        #expect(endpoint.displayName == "test@server.example:2222")
    }

    @Test("Leerzeichen am Rand werden entfernt")
    func trimsOuterWhitespace() throws {
        #expect(try Endpoint(parsing: "  test@192.0.2.10  ").host == "192.0.2.10")
        // Eingefügte Zeile mit Umbruch am Ende
        #expect(try Endpoint(parsing: "test@server.example:22\r\n").port == 22)
    }

    @Test("Das letzte @ trennt den Benutzer ab")
    func lastAtSeparatesUser() throws {
        let endpoint: Endpoint = try Endpoint(parsing: "test@domain@server.example")
        #expect(endpoint.user == "test@domain")
        #expect(endpoint.host == "server.example")
    }

    @Test("IPv6 in eckigen Klammern, mit und ohne Port")
    func ipv6() throws {
        let withPort: Endpoint = try Endpoint(parsing: "[2001:db8::1]:22")
        #expect(withPort.host == "2001:db8::1")
        #expect(withPort.port == 22)
        #expect(withPort.displayName == "[2001:db8::1]:22")
        #expect(try Endpoint(parsing: "[::1]").host == "::1")
        #expect(try Endpoint(parsing: "test@::1").host == "::1")
    }

    @Test("Host mit führendem Minus wird abgelehnt (S3)", arguments: [
        "-proxycmd x", "-proxycmd", "test@-oProxyCommand=x", "-load:22"
    ])
    func rejectsLeadingDashHost(_ text: String) {
        #expect(throws: InputError.leadingDash(.host)) { try Endpoint(parsing: text) }
    }

    @Test("Benutzer mit führendem Minus wird abgelehnt (S3)")
    func rejectsLeadingDashUser() {
        #expect(throws: InputError.leadingDash(.user)) { try Endpoint(parsing: "-l@server.example") }
    }

    @Test("Steuerzeichen werden abgelehnt (S3, S4)", arguments: [
        "server.example\nProxyMethod=5", "te\u{0}st@server.example", "server\u{7F}.example",
        "test\u{202E}@server.example", "server.\rexample"
    ])
    func rejectsControlCharacters(_ text: String) {
        #expect(throws: InputError.self) { try Endpoint(parsing: text) }
    }

    @Test("Leerzeichen im Inneren werden abgelehnt")
    func rejectsInnerWhitespace() {
        #expect(throws: InputError.whitespace(.host)) { try Endpoint(parsing: "server example") }
        #expect(throws: InputError.whitespace(.user)) { try Endpoint(parsing: "te st@server.example") }
    }

    @Test("Unzulässige Zeichen im Server", arguments: [
        "server/x", "server;rm", "ser$ver", "[::1", "[server.example]", "server..example:abc"
    ])
    func rejectsInvalidHostCharacters(_ text: String) {
        #expect(throws: InputError.self) { try Endpoint(parsing: text) }
    }

    @Test("Leere Teile werden abgelehnt")
    func rejectsEmptyParts() {
        #expect(throws: InputError.empty(.host)) { try Endpoint(parsing: "   ") }
        #expect(throws: InputError.empty(.user)) { try Endpoint(parsing: "@server.example") }
        #expect(throws: InputError.empty(.host)) { try Endpoint(parsing: "test@") }
    }

    @Test("Ungültige Ports", arguments: ["server.example:0", "server.example:65536", "server.example:",
                                          "server.example:+22", "server.example:2 2", "server.example:٢٢"])
    func rejectsInvalidPorts(_ text: String) {
        #expect(throws: InputError.self) { try Endpoint(parsing: text) }
    }

    @Test("Grenzwerte für Ports")
    func portBounds() throws {
        #expect(try Endpoint(parsing: "server.example:1").port == 1)
        #expect(try Endpoint(parsing: "server.example:65535").port == 65535)
    }

    @Test("Zu lange Namen werden abgelehnt")
    func rejectsOverlongNames() {
        let longHost: String = String(repeating: "a", count: 254)
        #expect(throws: InputError.tooLong(.host)) { try Endpoint(parsing: longHost) }
    }
}
