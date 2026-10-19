import Testing
@testable import TunnelTerminalCore

/// plink-Aufruf (Plan S3, S1): alles über die Sitzungsdatei, keine Werte als Kommandozeilenwörter.
@Suite("plink-Aufruf")
struct PlinkCommandTests {
    private let parent: [String: String] = [
        "HOME": "/home/test", "USER": "test", "LOGNAME": "test", "SSH_AUTH_SOCK": "/tmp/agent.sock",
        "LANG": "de_DE.UTF-8", "PUTTYSESSIONS": "/tmp/fremd", "PLINK_PROTOCOL": "telnet",
        "DYLD_INSERT_LIBRARIES": "/tmp/x.dylib", "TERM": "dumb", "PATH": "/usr/bin"
    ]

    @Test("Nur -load mit dem Sitzungsnamen")
    func argumentsAreOnlyLoad() throws {
        let command: PlinkCommand = try PlinkCommand(sessionName: "TunnelTerminal-Schnell-1", puttyDirectory: "/tmp/putty",
                                                     parentEnvironment: parent)
        #expect(command.arguments == ["-load", "TunnelTerminal-Schnell-1"])
    }

    @Test("Umgebung: feste Liste, PuTTY-Ordner der App, keine fremden Ablagen")
    func environmentIsAllowList() throws {
        let command: PlinkCommand = try PlinkCommand(sessionName: "s", puttyDirectory: "/tmp/putty",
                                                     parentEnvironment: parent)
        #expect(command.environment == [
            "COLORTERM=truecolor", "HOME=/home/test", "LANG=de_DE.UTF-8", "LOGNAME=test",
            "PUTTYDIR=/tmp/putty", "SSH_AUTH_SOCK=/tmp/agent.sock", "TERM=xterm-256color", "USER=test"
        ])
    }

    @Test("Ohne LANG wird UTF-8 gesetzt")
    func defaultLanguage() throws {
        let command: PlinkCommand = try PlinkCommand(sessionName: "s", puttyDirectory: "/p", parentEnvironment: [:])
        #expect(command.environment == ["COLORTERM=truecolor", "LANG=en_US.UTF-8", "PUTTYDIR=/p", "TERM=xterm-256color"])
    }

    @Test("Gespeicherte Sitzungen dürfen Leerzeichen und Gruppen im Namen haben (Argumentliste, keine Shell)")
    func acceptsSpacesInSessionNames() throws {
        let command: PlinkCommand = try PlinkCommand(sessionName: "Heim/Mein Server", puttyDirectory: "/p", parentEnvironment: [:])
        #expect(command.arguments == ["-load", "Heim/Mein Server"])
    }

    @Test("Ungültige Sitzungsnamen werden abgelehnt", arguments: ["", "-proxycmd", " a", "a ", "a\nb", "a\u{0}"])
    func rejectsSessionNames(_ name: String) {
        #expect(throws: InputError.self) {
            try PlinkCommand(sessionName: name, puttyDirectory: "/p", parentEnvironment: [:])
        }
    }

    @Test("Gespeichertes Passwort: nur -pwfile mit fd 3, nie das Passwort selbst (S1)")
    func passwordComesFromPipe() throws {
        let command: PlinkCommand = try PlinkCommand(sessionName: "Heim/Server", puttyDirectory: "/p", parentEnvironment: [:],
                                                     passwordFromPipe: true)
        #expect(command.arguments == ["-load", "Heim/Server", "-pwfile", "/dev/fd/3"])
    }
}
