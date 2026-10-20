import Testing
@testable import TunnelTerminalCore

/// Dateiübertragung über pscp (M6). pscp-Verhalten: docs/M6-Machbarkeit.md.
@Suite("Pfade auf dem Server")
struct RemotePathTests {
    @Test("Eingabe wird zum SFTP-Pfad: „~/“ und „~“ heißen persönlicher Ordner (sftp-server erweitert ~ nicht)", arguments: [
        ("dokumente/neu", "dokumente/neu"),
        ("/var/www", "/var/www"),
        ("~/www", "www"),
        ("~", ""),
        ("", ""),
        ("  /tmp/x.txt\n", "/tmp/x.txt"),
        ("~benutzer/x", "~benutzer/x")
    ])
    func normalizes(input: String, path: String) throws {
        #expect(try RemotePath(input).path == path)
    }

    @Test("Steuerzeichen und überlange Pfade werden abgelehnt", arguments: ["a\u{1B}[31m", "a\nb", "a\u{0}b", "x\u{202E}txt",
                                                                            String(repeating: "a", count: 4097)])
    func rejects(_ input: String) {
        #expect(throws: InputError.self) { try RemotePath(input) }
    }

    @Test("Name der heruntergeladenen Datei: letzter Teil des Pfads", arguments: [
        ("/var/log/syslog", "syslog"),
        ("bericht 2026.pdf", "bericht 2026.pdf"),
        ("~/.bashrc", ".bashrc"),
        ("a/b/../c", "c")
    ])
    func localFileName(input: String, name: String) throws {
        #expect(try RemotePath(input).localFileName == name)
    }

    @Test("Kein Dateiname: leer, Ordner mit „/“ am Ende, „.“ und „..“", arguments: ["", "~", "/var/log/", "a/..", "..", ".", "/"])
    func noLocalFileName(_ input: String) throws {
        #expect(try RemotePath(input).localFileName == nil)
    }
}

/// pscp-Aufruf (S3, S1): Optionen fest, Sitzung über `-load`, nur SFTP, nie eine Abfrage (`-batch`, S5). Der Server
/// steht – anders als bei plink – im Ziel „server:pfad“, weil pscp ihn sonst nicht kennt (docs/M6-Machbarkeit.md 2).
@Suite("pscp-Aufruf")
struct PscpCommandTests {
    private let options: [String] = ["-load", "TunnelTerminal-Schnell-1", "-sftp", "-batch"]

    private func upload(_ file: String, to folder: String = "www", host: String = "server.example",
                        password: Bool = false) throws -> [String] {
        try PscpCommand.upload(file, to: RemotePath(folder), host: host, sessionName: "TunnelTerminal-Schnell-1",
                               puttyDirectory: "/p", parentEnvironment: [:], passwordFromPipe: password).arguments
    }

    @Test("Hochladen: absolute Datei, Ziel „server:ordner“, kein „--“ (pscp 0.85 überspringt das Argument danach)")
    func uploadArguments() throws {
        #expect(try upload("/tmp/bericht 2026.pdf") == options + ["/tmp/bericht 2026.pdf", "server.example:www"])
    }

    @Test("Leerer Zielordner = persönlicher Ordner; IPv6 in eckigen Klammern")
    func uploadTargets() throws {
        #expect(try upload("/tmp/a.txt", to: "~").last == "server.example:")
        #expect(try upload("/tmp/a.txt", host: "2001:db8::1").last == "[2001:db8::1]:www")
    }

    @Test("Passwort nur über fd 3, nach -load (S1)")
    func passwordFromPipe() throws {
        #expect(try upload("/tmp/a.txt", password: true) == options + ["-pwfile", "/dev/fd/3", "/tmp/a.txt", "server.example:www"])
    }

    @Test("Hochladen abgelehnt: relativer Pfad, „-“ vorn, Steuerzeichen, „\\“ im Namen (pscp kürzt den Namen dort)",
          arguments: ["a.txt", "-r", "/tmp/a\nb", "/tmp/a\\b.txt"])
    func uploadRejects(_ file: String) {
        #expect(throws: InputError.self) { try upload(file) }
    }

    @Test("Server wie bei der Schnellverbindung geprüft (kein „-“, „@“, „:“ allein)",
          arguments: ["-oProxyCommand=x", "test@server.example", "server.example:22", ""])
    func rejectsHosts(_ host: String) {
        #expect(throws: InputError.self) { try upload("/tmp/a.txt", host: host) }
    }

    @Test("Server mit nur einem Zeichen: pscp hielte „x:www“ für einen Pfad auf dem Mac (Laufwerksbuchstabe, pscp.c colon())")
    func rejectsSingleCharacterHost() {
        #expect(throws: InputError.singleCharacterHost) { try upload("/tmp/a.txt", host: "x") }
        #expect(throws: InputError.singleCharacterHost) {
            try PscpCommand.list(RemotePath(""), host: "x", sessionName: "s", puttyDirectory: "/p", parentEnvironment: [:],
                                 passwordFromPipe: false)
        }
    }

    @Test("Herunterladen: Joker im Pfad maskiert, damit pscp genau diese eine Datei lädt; Ziel ist eine eigene Datei")
    func downloadArguments() throws {
        let command: PscpCommand = try .download(RemotePath("~/a*b?[c]\\d.txt"), to: "/tmp/.teil", host: "server.example",
                                                 sessionName: "TunnelTerminal-Schnell-1", puttyDirectory: "/p",
                                                 parentEnvironment: [:], passwordFromPipe: false)
        #expect(command.arguments == options + ["server.example:a\\*b\\?\\[c\\]\\\\d.txt", "/tmp/.teil"])
    }

    @Test("Herunterladen nur mit Dateinamen")
    func downloadNeedsFile() {
        #expect(throws: InputError.notAFile) {
            try PscpCommand.download(RemotePath("/var/log/"), to: "/tmp/x", host: "server.example", sessionName: "s",
                                     puttyDirectory: "/p", parentEnvironment: [:], passwordFromPipe: false)
        }
    }

    @Test("Ordner auflisten (Prüfung vor dem Überschreiben)")
    func listArguments() throws {
        let command: PscpCommand = try .list(RemotePath("www"), host: "server.example", sessionName: "TunnelTerminal-Schnell-1",
                                             puttyDirectory: "/p", parentEnvironment: [:], passwordFromPipe: false)
        #expect(command.arguments == options + ["-q", "-ls", "server.example:www"])
    }

    @Test("Umgebung wie bei plink: feste Liste mit dem PuTTY-Ordner der App")
    func environment() throws {
        let command: PscpCommand = try .list(RemotePath(""), host: "server.example", sessionName: "s", puttyDirectory: "/p",
                                             parentEnvironment: ["HOME": "/home/test", "DYLD_INSERT_LIBRARIES": "/tmp/x"],
                                             passwordFromPipe: false)
        #expect(command.environment == ["COLORTERM=truecolor", "HOME=/home/test", "LANG=en_US.UTF-8", "PUTTYDIR=/p",
                                        "TERM=xterm-256color"])
    }

    @Test("Benutzer und Server für pscp wie plink sie liest, IPv6 ohne Klammern")
    func transferAddress() throws {
        var file: SessionFile = SessionFile()
        try file.setValue("test@[2001:db8::1]:2222", forKey: "HostName")
        #expect(file.transferAddress.user == "test")
        #expect(file.transferAddress.host == "2001:db8::1")
        try file.setValue(" server.example", forKey: "HostName")
        try file.setValue("anderer", forKey: "UserName")
        #expect(file.transferAddress.user == "anderer")
        #expect(file.transferAddress.host == "server.example")
    }
}

/// Ausgabe von pscp (gemessen in docs/M6-Machbarkeit.md; Beispiele mit Platzhaltern, S14).
@Suite("pscp-Ausgabe")
struct PscpOutputTests {
    @Test("Fortschritt: Prozent der letzten vollständigen Zeile (pscp schreibt sie mit \\r neu, etwa einmal je Sekunde)")
    func percent() {
        let first: String = "\rgross.bin                 | 4 kB |   4.0 kB/s | ETA: 28:26:39 |   0%"
        let later: String = "\rgross.bin                 | 101544 kB | 101544.0 kB/s | ETA: 00:00:03 |  24%"
        #expect(PscpOutput.percent(in: first) == 0)
        #expect(PscpOutput.percent(in: first + later) == 24)
        #expect(PscpOutput.percent(in: later + "\rgross.bin                 | 409600 kB | 204800.0 kB/s | ETA: 00:00:00 | 100%\r\n") == 100)
        #expect(PscpOutput.percent(in: later + "\rgross.bin                 | 358548 kB | 179274.0 kB/s | ETA: 00:00:00 |  8") == 24)
        #expect(PscpOutput.percent(in: "Making proxy SSH connection to server.example port 22\r\n") == nil)
    }

    private let listing: String = """
        Listing directory /srv/ziel\r
        drwx------    4 test staff         128 Oct 20 18:13 .\r
        drwx------    3 test staff          96 Oct 20 18:13 ..\r
        -rw-r--r--    1 test staff    391000064 Oct 20 18:13 gross.bin\r
        -rw-r--r--    1 test staff          13 Oct  5  2025 mit leer zeichen.txt\r

        """

    @Test("Ordnerinhalt: Datei vorhanden, wenn eine Zeile auf „ Name“ endet (im Zweifel ja: dann fragt die App)")
    func listingContains() async {
        let names: [String] = ["gross.bin", "mit leer zeichen.txt", "zeichen.txt", "bin", "ziel", "neu.txt"]
        #expect(await PscpOutput.existing(names, in: listing) == ["gross.bin", "mit leer zeichen.txt", "zeichen.txt"])
    }

    @Test("Ordnerinhalt: Groß-/Kleinschreibung zählt nicht (ein Mac als Server überschriebe „Gross.bin“ mit „GROSS.bin“)")
    func listingIgnoresCase() async {
        let names: [String] = ["GROSS.bin", "Mit Leer Zeichen.TXT", "GROSS.bi"]
        #expect(await PscpOutput.existing(names, in: listing) == ["GROSS.bin", "Mit Leer Zeichen.TXT"])
    }

    @Test("Fehler erkennen: Passwort nötig oder abgelehnt, Hostschlüssel unbekannt")
    func knownFailures() {
        #expect(PscpOutput.failure(in: "Keyboard-interactive authentication prompts from server:\r\nFATAL ERROR: Cannot answer interactive prompts in batch mode\r\n") == .passwordNeeded)
        #expect(PscpOutput.failure(in: "Configured password was not accepted\r\nFATAL ERROR: Cannot answer interactive prompts in batch mode\r\n") == .passwordRejected)
        #expect(PscpOutput.failure(in: "The host key is not cached for this server:\r\n  server.example (port 22)\r\nConnection abandoned.\r\nFATAL ERROR: Cannot confirm a host key in batch mode\r\n") == .hostKeyUnknown)
    }

    @Test("Sonst die letzte Meldung von pscp, ohne Vorsilbe, Steuerzeichen sichtbar, gekürzt")
    func otherFailures() {
        #expect(PscpOutput.failure(in: "pscp: unable to open /srv/ziel/a.txt: permission denied\r\n") == .other("unable to open /srv/ziel/a.txt: permission denied"))
        #expect(PscpOutput.failure(in: "\rx | 4 kB | 4.0 kB/s | ETA: 00:00:01 |  50%\r\nFATAL ERROR: Network error: Connection reset by peer\r\n") == .other("Network error: Connection reset by peer"))
        #expect(PscpOutput.failure(in: "pscp: a\u{1B}[2Jb\r\n") == .other("a\\u{1B}[2Jb"))
        #expect(PscpOutput.failure(in: "") == .other("pscp ist ohne Meldung beendet."))
        let long: TransferFailure = PscpOutput.failure(in: String(repeating: "x", count: 1_000))
        #expect(long == .other(String(repeating: "x", count: 300) + "…"))
    }

    /// Robustheit (RL 3.2 Regel 7): Ausgabe von pscp und vom Server ist fremd – zufällig zusammengesetzte Stücke aus den
    /// Bausteinen echter Zeilen dürfen nie abstürzen, Prozente bleiben 0…100, Meldungen kurz und ohne Steuerzeichen.
    @Test("Zufällige Ausgabe: kein Absturz, Prozent 0…100, Meldung sichtbar und kurz")
    func randomOutput() async {
        var generator: SeededGenerator = SeededGenerator(seed: 0x5C9)
        let pieces: [String] = [" | ", "%", "\r", "\n", "\r\n", "ETA: ", " kB", "100", "-1", "999999999999999999999", "42",
                                "Listing directory ", "pscp: ", "FATAL ERROR: ", "\u{1B}[2J", "ä", "\u{202E}", "  ", "|", "x"]
        for _ in 0..<2_000 {
            var text: String = ""
            for _ in 0..<Int.random(in: 0...40, using: &generator) { text += pieces[Int.random(in: 0..<pieces.count, using: &generator)] }
            if let percent = PscpOutput.percent(in: text) { #expect((0...100).contains(percent)) }
            _ = await PscpOutput.existing(["x"], in: text)
            if case .other(let message) = PscpOutput.failure(in: text) {
                #expect(message.count <= 301)
                #expect(!message.unicodeScalars.contains { $0.value == 0x1B || $0.value == 0x202E })
            }
        }
    }
}
