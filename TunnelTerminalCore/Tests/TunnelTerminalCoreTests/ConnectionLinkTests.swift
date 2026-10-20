import Testing
@testable import TunnelTerminalCore

/// Links `ssh://` und `telnet://` aus anderen Apps (Plan M7, S6): nur Benutzer, Server und Port.
@Suite("Links lesen")
struct ConnectionLinkTests {
    @Test("ssh:// mit Benutzer, Server und Port")
    func sshWithUserHostPort() throws {
        let link: ConnectionLink = try ConnectionLink(parsing: "ssh://test@server.example:2222")
        #expect(link.connectionProtocol == .ssh)
        #expect(link.endpoint == (try Endpoint(user: "test", host: "server.example", port: 2222)))
        #expect(link.address == "ssh://test@server.example:2222")
    }

    @Test("telnet:// ohne Benutzer, mit Schrägstrich am Ende")
    func telnetHostOnly() throws {
        let link: ConnectionLink = try ConnectionLink(parsing: "telnet://192.0.2.10/")
        #expect(link.connectionProtocol == .telnet)
        #expect(link.endpoint == (try Endpoint(host: "192.0.2.10")))
        #expect(link.address == "telnet://192.0.2.10")
    }

    @Test("Schema ohne Rücksicht auf Groß/klein, leerer Port = Standardport")
    func schemeCaseAndEmptyPort() throws {
        #expect(try ConnectionLink(parsing: "SSH://test@server.example:22/").endpoint.port == 22)
        #expect(try ConnectionLink(parsing: "ssh://server.example:").endpoint.port == nil)
    }

    @Test("IPv6 in Klammern, Zone als %25, Prozent-Kodierung im Benutzer")
    func ipv6AndPercentEncoding() throws {
        let ipv6: ConnectionLink = try ConnectionLink(parsing: "ssh://[2001:db8::1]:2200")
        #expect(ipv6.endpoint.host == "2001:db8::1")
        #expect(ipv6.endpoint.port == 2200)
        #expect(ipv6.address == "ssh://[2001:db8::1]:2200")
        #expect(try ConnectionLink(parsing: "ssh://[2001:db8::1%25en0]").endpoint.host == "2001:db8::1%en0")
        #expect(try ConnectionLink(parsing: "ssh://t%C3%A9st@server.example").endpoint.user == "tést")
    }

    @Test("Optionen über den Benutzer oder Server werden abgelehnt (S3, S6)", arguments: [
        ("ssh://-oProxyCommand=x@server.example", InputError.leadingDash(.user)),
        ("ssh://-oProxyCommand%3Dx@server.example", .leadingDash(.user)),
        ("ssh://%2Dload@server.example", .leadingDash(.user)),
        ("ssh://test@-server.example", .leadingDash(.host)),
        ("ssh://test@%2Dproxycmd", .leadingDash(.host))
    ])
    func rejectsOptions(link: String, error: InputError) {
        #expect(throws: error) { try ConnectionLink(parsing: link) }
    }

    @Test("Passwort, Parameter, Pfad, Abfrage und Anker werden abgelehnt", arguments: [
        ("ssh://test:geheim@server.example", InputError.linkHasPassword),
        ("telnet://test:@server.example/", .linkHasPassword),
        ("ssh://test%3Ageheim@server.example", .linkHasPassword),
        ("ssh://test%3Bfingerprint=ssh-ed25519-AAAA@server.example", .linkHasExtras),
        ("ssh://test;fingerprint=ssh-ed25519-AAAA@server.example", .linkHasExtras),
        ("ssh://server.example/etc/passwd", .linkHasExtras),
        ("ssh://server.example//", .linkHasExtras),
        ("ssh://server.example?x=1", .linkHasExtras),
        ("ssh://server.example#anker", .linkHasExtras)
    ])
    func rejectsExtras(link: String, error: InputError) {
        #expect(throws: error) { try ConnectionLink(parsing: link) }
    }

    @Test("Nur ssh und telnet", arguments: [
        "http://server.example", "sftp://server.example", "rlogin://server.example", "ssh:server.example",
        "x-ssh://server.example", "file:///etc/passwd", ""
    ])
    func rejectsOtherSchemes(link: String) {
        #expect(throws: InputError.unsupportedLink) { try ConnectionLink(parsing: link) }
    }

    @Test("Kaputte Adressen, Ports und Kodierungen", arguments: [
        ("ssh://", InputError.empty(.host)),
        ("ssh://test@", .empty(.host)),
        ("ssh://@server.example", .empty(.user)),
        ("ssh://a@b@server.example", .invalidCharacter(.link)),
        // Kodiert dürfen „@“ und „/“ die angezeigte Adresse nicht verfälschen (Prüfer M7, Befund 2)
        ("ssh://root%40prod.bank.example%2Flogin@server.example", .invalidCharacter(.user)),
        ("ssh://a%40b@server.example", .invalidCharacter(.user)),
        ("ssh://test%2F@server.example", .invalidCharacter(.user)),
        ("ssh://server.example:0", .invalidPort),
        ("ssh://server.example:65536", .invalidPort),
        ("ssh://server.example:22a", .invalidPort),
        ("ssh://server.example:+22", .invalidPort),
        ("ssh://server.example:22:33", .invalidCharacter(.host)),
        ("ssh://[2001:db8::1", .invalidCharacter(.host)),
        ("ssh://[2001:db8::1]x", .invalidCharacter(.host)),
        ("ssh://[server.example]", .invalidCharacter(.host)),
        ("ssh://test%ZZ@server.example", .invalidCharacter(.user)),
        ("ssh://test@server%ZZ.example", .invalidCharacter(.host)),
        ("ssh://ser*ver.example", .invalidCharacter(.host))
    ])
    func rejectsBrokenAddresses(link: String, error: InputError) {
        #expect(throws: error) { try ConnectionLink(parsing: link) }
    }

    @Test("Steuer- und Leerzeichen, roh oder kodiert (S4)", arguments: [
        ("ssh://test@server.example\n", InputError.controlCharacter(.link)),
        ("ssh://\u{202E}evil@server.example", .controlCharacter(.link)),
        ("ssh://test@serv er.example", .whitespace(.link)),
        ("ssh://test%0A@server.example", .controlCharacter(.user)),
        ("ssh://%E2%80%AEevil@server.example", .controlCharacter(.user)),
        ("ssh://test%20x@server.example", .whitespace(.user)),
        ("ssh://test@server.example%0A-oProxyCommand", .controlCharacter(.host)),
        ("ssh://te%00st@server.example", .controlCharacter(.user))
    ])
    func rejectsControlCharacters(link: String, error: InputError) {
        #expect(throws: error) { try ConnectionLink(parsing: link) }
    }

    @Test("Zu lange Links werden abgelehnt")
    func rejectsLongLinks() {
        #expect(throws: InputError.tooLong(.link)) {
            try ConnectionLink(parsing: "ssh://" + String(repeating: "a", count: ConnectionLink.maximumLength))
        }
    }

    @Test("Robustheit: zufällig veränderte Links bringen den Leser nie zum Absturz und nie an den Regeln vorbei")
    func survivesMutations() {
        var generator: SeededGenerator = SeededGenerator(seed: 0x11F7)
        // Einzelzeichen und kodierte Bausteine („%40“ = „@“, „%3A“ = „:“, „%3B“ = „;“, „%2F“ = „/“)
        let alphabet: [String] = "ssh://telnet:@[]%25-;?#/.:0123456789abcdefABCDEF xX\n\u{202E}é".map(String.init)
            + ["%40", "%3A", "%3B", "%2F", "%2D", "%0A"]
        let bases: [String] = ["ssh://test@server.example:2222/", "telnet://[2001:db8::1%25en0]:23", "ssh://t%C3%A9st@192.0.2.10"]
        for _ in 0..<5000 {
            var characters: [String] = bases[Int.random(in: 0..<bases.count, using: &generator)].map(String.init)
            for _ in 0..<Int.random(in: 1...6, using: &generator) {
                let index: Int = Int.random(in: 0..<characters.count, using: &generator)
                let character: String = alphabet[Int.random(in: 0..<alphabet.count, using: &generator)]
                switch Int.random(in: 0..<3, using: &generator) {
                case 0: characters[index] = character
                case 1: characters.remove(at: index)
                default: characters.insert(character, at: index)
                }
                if characters.isEmpty { characters = ["s"] }
            }
            guard let link = try? ConnectionLink(parsing: characters.joined()) else { continue }
            // Was durchkommt: kein Passwort, kein Parameter, Benutzer und Server eindeutig, nie eine Option (S3, S6)
            let user: String = link.endpoint.user ?? ""
            #expect(!user.contains(where: { ":;@/".contains($0) }))
            #expect(!link.endpoint.host.contains(where: { "@/;".contains($0) }))
            #expect(link.address.filter { $0 == "@" }.count == (link.endpoint.user == nil ? 0 : 1))
            #expect(!link.endpoint.host.hasPrefix("-") && !user.hasPrefix("-"))
        }
    }
}
