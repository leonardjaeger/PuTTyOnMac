import Foundation
import Testing
@testable import TunnelTerminalCore

/// Härtung (Plan Abschnitt 5, RL 3.2 Regel 7): Leser für fremde Dateien bekommen zufällig veränderte Eingaben.
/// Kein Leser darf die App beenden (Überlauf, Index), und was gelesen wird, muss die Regeln S3/S4 einhalten.
/// Reproduzierbar über feste Startwerte (`SeededGenerator`). `.reg` und `ssh://` stehen in ihren eigenen Suiten.
@Suite("Robustheit")
struct RobustnessTests {
    /// Sitzung mit allen Schlüsseln, die die App auswertet (nur Platzhalter, S14).
    private static let session: String = """
        Present=1\r
        HostName=test@[2001:db8::1]:2222
        LogHost=
        PortNumber=22
        Protocol=ssh
        UserName=test
        TerminalType=xterm-256color
        PublicKeyFile=/tmp/test.ppk
        ProxyMethod=6
        ProxyType=4
        ProxyHost=Gruppe/Sprung
        ProxyPort=1080
        ProxyUsername=test
        ProxyPassword=geheim
        ProxyTelnetCommand=connect %host %port\\n\\x41%%%proxyhost %PASS\\
        ProxyLocalhost=0
        PortForwardings=L8080=localhost:80,4R2222=192.0.2.10:22,D1080,6L127.0.0.1:3000=[::1]:3000,L2=x\\,y:1
        LocalPortAcceptAll=0
        RemoteCommand=uptime
        AgentFwd=1
        LogType=2
        LogFileName=putty.log
        GSSCustom=
        SSHManualHostKeys=
        SerialLine=/dev/cu.test
        SerialSpeed=115200
        SerialDataBits=8
        SerialStopHalfbits=2
        SerialParity=0
        SerialFlowControl=1
        PingIntervalSecs=30
        TCPKeepalives=1
        Compression=0
        TunnelTerminalProfile=00000000-0000-0000-0000-000000000001
        ohne Gleichheitszeichen

        """

    /// Bausteine, die Leser gern aus dem Tritt bringen, zusätzlich zu einzelnen Zufallsbytes.
    private static let tokens: [[UInt8]] = [
        "=", "\r", "\n", "-", ",", "\\", ":", "[", "]", "%", "@", "/", " ", "\t",
        "99999999999999999999", "-2147483649", "4294967301", "0", "5", "6", "8", "serial", "telnet", "raw",
        "%host", "\\x", "\\xZ", "%%", "..", "/dev/", "\u{202E}", "é"
    ].map { Array($0.utf8) } + [[0xFF], [0xC3], [0x00]]

    private static func mutate(_ base: [UInt8], using generator: inout SeededGenerator) -> [UInt8] {
        var bytes: [UInt8] = base
        for _ in 0..<Int.random(in: 1...8, using: &generator) {
            let index: Int = Int.random(in: 0...bytes.count, using: &generator)
            let piece: [UInt8] = Bool.random(using: &generator)
                ? [UInt8.random(in: 0...255, using: &generator)]
                : tokens[Int.random(in: 0..<tokens.count, using: &generator)]
            switch Int.random(in: 0..<3, using: &generator) {
            case 0 where index < bytes.count:
                let end: Int = min(bytes.count, index + Int.random(in: 1...12, using: &generator))
                bytes.replaceSubrange(index..<end, with: piece)
            case 1 where index < bytes.count:
                bytes.remove(at: index)
            default:
                bytes.insert(contentsOf: piece, at: index)
            }
        }
        return bytes
    }

    @Test("Sitzungsdatei: zufällig veränderte Dateien – kein Absturz, Rundlauf byte-gleich, Auswertung ohne Absturz")
    func sessionFileSurvivesMutations() {
        var generator: SeededGenerator = SeededGenerator(seed: 0x4A27)
        let base: [UInt8] = Array(Self.session.utf8)
        for _ in 0..<4000 {
            let bytes: [UInt8] = Self.mutate(base, using: &generator)
            guard let file = try? SessionFile(contents: Data(bytes)) else {
                #expect(bytes.contains(0), "nur Dateien mit NUL werden abgelehnt")
                continue
            }
            #expect(file.contents == Data(bytes), "unveränderte Datei kommt byte-gleich zurück")
            Self.exercise(file)
            Self.rewrite(file)
        }
    }

    /// Alles, was Seitenleiste, Inspektor, Editor, Rückfragen und Verbindungsaufbau aus einer Datei lesen.
    static func exercise(_ file: SessionFile) {
        _ = file.entries
        _ = file.warnings.map(\.message)
        // Proxy-Kette: dieselbe Datei unter jedem Namen – endet mit Ergebnis oder Fehler, nie endlos
        _ = try? SessionWarning.requiringConfirmation(for: file, named: "Gruppe/Sprung") { _ in file }
        _ = ConnectionSummary(file: file)
        for forwarding in file.portForwardings {
            _ = (forwarding.title, forwarding.listenPort, forwarding.storageKey, forwarding.listensBeyondLoopback)
        }
        _ = file.localListenPorts
        _ = (file.proxyKind, file.hasUndefinedProxy, file.proxyDescription, file.proxyHost, file.proxyPort)
        _ = (file.serialLine, file.listAddress, file.serialSpeed, file.serialDataBits, file.serialStopBits)
        _ = (file.serialParity, file.serialFlowControl)
        _ = (file.passwordTarget, file.passwordUnavailableReason, file.hostKeyServer, file.transferAddress)
        _ = (file.profileID, file.sessionLogEnabled, file.portNumber, file.keepaliveSeconds, file.otherEntryCount)
        _ = (file.connectionProtocol, file.terminalType, file.publicKeyFile, file.remoteCommand)
    }

    /// Wie der Editor beim Sichern: gelesene Werte zurückschreiben. Was angenommen wird, steht danach genau so in der
    /// Datei und ohne Zeilenumbruch oder NUL (S4).
    private static func rewrite(_ file: SessionFile) {
        var copy: SessionFile = file
        if (try? copy.setHostName(file.hostName)) != nil { #expect(copy.hostName == file.hostName) }
        if (try? copy.setUserName(file.userName)) != nil { #expect(copy.userName == file.userName) }
        if (try? copy.setTerminalType(file.terminalType)) != nil { #expect(copy.terminalType == file.terminalType) }
        if (try? copy.setRemoteCommand(file.remoteCommand)) != nil { #expect(copy.remoteCommand == file.remoteCommand) }
        if (try? copy.setPortForwardings(file.portForwardings)) != nil {
            #expect(copy.portForwardings == file.portForwardings, "Weiterleitungen überstehen Lesen und Schreiben")
        }
        if (try? copy.setProxyHost(file.proxyHost)) != nil { #expect(copy.proxyHost == file.proxyHost) }
        if (try? copy.setSerialLine(file.serialLine)) != nil { #expect(copy.serialLine == file.serialLine) }
        guard let reread = try? SessionFile(contents: copy.contents) else {
            Issue.record("geschriebene Datei ist nicht lesbar")
            return
        }
        #expect(reread == copy)
        for key in ["HostName", "UserName", "TerminalType", "RemoteCommand", "PortForwardings", "ProxyHost", "SerialLine"] {
            #expect(!(reread.value(forKey: key) ?? "").contains(where: { $0 == "\n" || $0 == "\0" }))
        }
    }

    @Test("Bekannte Hostschlüssel: zufällig veränderte sshhostkeys – kein Absturz, Entfernen lässt andere Zeilen stehen")
    func knownHostKeysSurviveMutations() {
        var generator: SeededGenerator = SeededGenerator(seed: 0x55D)
        let base: [UInt8] = Array("""
            ssh-ed25519@22:server.example 0x57741977920863dda800962bcf07537e6cdb7636caf1132e6948554ea38a73df,0x3da590589456d9724387b8c6b7755bde15eaae0ad34d62b36e10d46d7e5635ab
            ecdsa-sha2-nistp256@22:[2001:db8::1] nistp256,0x1362b65c8f1f99c7bbe282af31fd96be4c346c6d20ab7bcd88f2aa5dda028a6e,0xf9b98e03ebe1ffd1110c1abeab54ee431271338ad23e197b55786e4faa145365
            rsa2@2223:192.0.2.7 0x10001,0xc81b33f6843e6b58007ca0e7c475320e9bdba156adafd772a6cfed8712461ff6
            dss@22:server.example 0x1,0x2,0x3,0x4

            """.utf8)
        for _ in 0..<4000 {
            let bytes: [UInt8] = Self.mutate(base, using: &generator)
            var keys: KnownHostKeys = KnownHostKeys(contents: Data(bytes))
            let entries: [KnownHostKey] = keys.entries
            for entry in entries {
                _ = (entry.fingerprint, entry.typeTitle, entry.id)
                #expect((1...65_535).contains(entry.port))
                _ = keys.entries(host: entry.host, port: entry.port)
            }
            guard let removed = entries.randomElement(using: &generator) else { continue }
            let before: Int = entries.count
            keys.remove([removed.id])
            #expect(keys.entries.allSatisfy { $0.id != removed.id })
            #expect(keys.entries.count == before - entries.filter { $0.id == removed.id }.count)
        }
    }

    @Test("Namen von Sitzungsdateien: zufällige Dateinamen lassen sich nur dekodieren, wenn der Rundlauf stimmt")
    func sessionFileNamesSurviveMutations() {
        var generator: SeededGenerator = SeededGenerator(seed: 0xF11E)
        let base: [UInt8] = Array("Gruppe%2FServer%20%C3%A4%25-1.example".utf8)
        for _ in 0..<4000 {
            let bytes: [UInt8] = Self.mutate(base, using: &generator)
            guard let name = SessionName.decode(fileName: String(decoding: bytes, as: UTF8.self)) else { continue }
            _ = (SessionName.group(of: name), SessionName.title(of: name), SessionName.fileKey(name))
            if !name.isEmpty { #expect(SessionName.decode(fileName: SessionFile.fileName(forSessionNamed: name)) == name) }
        }
    }

    @Test("Schnellverbindung: zufällige Eingaben – nie ein Server oder Benutzer, den plink als Option liest (S3)")
    func endpointSurvivesMutations() {
        var generator: SeededGenerator = SeededGenerator(seed: 0xE9D)
        let base: [UInt8] = Array("test@[2001:db8::1]:2222".utf8)
        for _ in 0..<4000 {
            let bytes: [UInt8] = Self.mutate(base, using: &generator)
            guard let endpoint = try? Endpoint(parsing: String(decoding: bytes, as: UTF8.self)) else { continue }
            let user: String = endpoint.user ?? ""
            #expect(!endpoint.host.isEmpty && !endpoint.host.hasPrefix("-") && !user.hasPrefix("-"))
            #expect(!(endpoint.host + user).unicodeScalars.contains { $0.properties.generalCategory == .control || $0 == " " })
            if let port = endpoint.port { #expect((1...65_535).contains(port)) }
        }
    }

    @Test("Profile aus den Einstellungen: zufällig veränderte Daten – Standard zuerst, Werte im erlaubten Bereich")
    func profilesSurviveMutations() throws {
        var generator: SeededGenerator = SeededGenerator(seed: 0x9F0)
        let custom: TerminalProfile = TerminalProfile(id: UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)),
                                                      name: "Dunkel", fontName: "Menlo", fontSize: 14, colorScheme: .dark,
                                                      scrollbackLines: 10_000, cursorShape: .block, bell: .off)
        let base: [UInt8] = try [UInt8](JSONEncoder().encode([TerminalProfile.standard, custom]))
        for _ in 0..<3000 {
            let profiles: [TerminalProfile] = TerminalProfile.list(from: Data(Self.mutate(base, using: &generator)))
            #expect(profiles.first?.id == TerminalProfile.standardID)
            #expect(Set(profiles.map(\.id)).count == profiles.count)
            for profile in profiles {
                #expect(TerminalProfile.fontSizes.contains(profile.fontSize))
                #expect(TerminalProfile.scrollbackRange.contains(profile.scrollbackLines))
            }
        }
    }
}
