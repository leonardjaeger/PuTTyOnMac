// PROTOTYP M0 – Wegwerfcode. Beantwortet nur die Machbarkeitsfragen aus M0
// (plink in SwiftTerm, Passwort per Pipe, Sandbox, Schlüsseldatei, Seriell).
// Nicht ins App-Projekt übernehmen.
import AppKit
import os
import Security
import SwiftTerm

let log = Logger(subsystem: "de.leonardjaeger.sshapp.m0prototyp", category: "m0")
let inSandbox = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
let keychainService = "SSH-App-M0-Test"

struct PrototypeError: Error, CustomStringConvertible {
    let description: String
    init(_ text: String) { description = text }
}

// MARK: - Pfade und Umgebung

func plinkPath() -> String {
    Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/plink").path
}

func supportDirectory(_ name: String) throws -> URL {
    let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                           appropriateFor: nil, create: true)
    let dir = base.appendingPathComponent("SSH-App-Prototyp/\(name)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
    return dir
}

/// Eigener PuTTY-Ordner, damit nichts mit einer Homebrew-PuTTY in ~/.putty kollidiert.
func childEnvironment() throws -> [String] {
    var env: [String] = Terminal.getEnvironmentVariables(termName: "xterm-256color")
    let puttyDir: URL = try supportDirectory("putty")
    try writeDefaultSettings(puttyDir)
    env.append("PUTTYDIR=\(puttyDir.path)")
    if let sock = ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"] {
        env.append("SSH_AUTH_SOCK=\(sock)")
    }
    return env
}

/// Unix-plink 0.85 übernimmt $TERM nicht (platform_default_s fragt „TermType“ ab, die Einstellung heißt
/// aber „TerminalType“) und meldet immer „xterm“. Deshalb Terminaltyp über „Default Settings“ im eigenen PUTTYDIR.
func writeDefaultSettings(_ puttyDir: URL) throws {
    let sessions: URL = puttyDir.appendingPathComponent("sessions", isDirectory: true)
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
    try Data("TerminalType=xterm-256color\n".utf8)
        .write(to: sessions.appendingPathComponent("Default%20Settings"), options: .atomic)
}

/// Ziel `benutzer@localhost`; der Benutzername kommt zur Laufzeit und steht nie in Dateien (S14).
func localTarget() throws -> String {
    let user: String = NSUserName()
    let printable: Bool = user.unicodeScalars.allSatisfy { $0.value > 0x20 && $0.value != 0x7f }
    guard !user.isEmpty, !user.hasPrefix("-"), printable else {
        throw PrototypeError("Benutzername ungeeignet")
    }
    return "\(user)@localhost"
}

// MARK: - Schlüsselbund (Testeintrag)

func keychainQuery() -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: keychainService,
     kSecAttrAccount as String: NSUserName()]
}

func storeTestPassword(_ password: String) throws {
    SecItemDelete(keychainQuery() as CFDictionary)
    var add: [String: Any] = keychainQuery()
    add[kSecValueData as String] = Data(password.utf8)
    add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    let status: OSStatus = SecItemAdd(add as CFDictionary, nil)
    guard status == errSecSuccess else { throw PrototypeError("SecItemAdd: \(status)") }
}

func loadTestPassword() throws -> Data {
    var query: [String: Any] = keychainQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else {
        throw PrototypeError("Kein Testpasswort im Schlüsselbund (Status \(status)) – zuerst „Testpasswort ablegen…“")
    }
    return data
}

// MARK: - Pipe für -pwfile (S1: nie -pw, nie Datei auf der Platte)

/// Schreibt Geheimnis + Zeilenende in eine Pipe, schließt das Schreibende und gibt das Leseende zurück.
func secretPipe(_ secret: Data, inheritable: Bool) throws -> Int32 {
    guard !secret.isEmpty, secret.count < 4096, !secret.contains(0x0a), !secret.contains(0x0d) else {
        throw PrototypeError("Passwort leer, zu lang oder mit Zeilenumbruch")
    }
    var fds: [Int32] = [-1, -1]
    guard pipe(&fds) == 0 else { throw PrototypeError("pipe: errno \(errno)") }
    _ = fcntl(fds[1], F_SETFD, FD_CLOEXEC)
    _ = fcntl(fds[0], F_SETFD, inheritable ? 0 : FD_CLOEXEC)
    var bytes: [UInt8] = [UInt8](secret)
    bytes.append(0x0a)
    let count: Int = bytes.count
    let written: Int = bytes.withUnsafeBytes { write(fds[1], $0.baseAddress, $0.count) }
    _ = bytes.withUnsafeMutableBytes { memset_s($0.baseAddress, $0.count, 0, $0.count) }
    close(fds[1])
    guard written == count else {
        close(fds[0])
        throw PrototypeError("Pipe nicht vollständig beschrieben")
    }
    return fds[0]
}

// MARK: - Weg A: SwiftTerm LocalProcessTerminalView (forkpty)

/// forkpty vererbt jeden Deskriptor ohne FD_CLOEXEC; das Passwort kommt deshalb unter /dev/fd/<n>
/// mit beliebigem n an. Welche Deskriptoren plink sonst noch erbt, zeigt 05-prozesse.sh.
@MainActor
final class ForkptySession: NSObject, LocalProcessTerminalViewDelegate, NSWindowDelegate {
    let window: NSWindow
    let term: LocalProcessTerminalView
    let label: String

    init(label: String) {
        self.label = label
        term = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 820, height: 500))
        window = NSWindow(contentRect: term.frame, styleMask: [.titled, .closable, .resizable, .miniaturizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "A · \(label)"
        window.contentView = term
        window.isReleasedWhenClosed = false
        window.delegate = self
        term.processDelegate = self
    }

    func start(executable: String, args: [String], inheritedFD: Int32? = nil) throws {
        defer { if let fd = inheritedFD { close(fd) } }   // nur das Kind behält das Leseende – auch bei Fehlern
        let env: [String] = try childEnvironment()
        term.feed(text: "[Prototyp] Weg A (forkpty) · Sandbox: \(inSandbox ? "ja" : "nein") · \(label)\r\n")
        term.feed(text: "[Prototyp] \(executable.split(separator: "/").last ?? "") \(args.joined(separator: " "))\r\n\r\n")
        window.center()
        window.makeKeyAndOrderFront(nil)
        term.startProcess(executable: executable, args: args, environment: env)
        log.info("Weg A gestartet: \(self.label, privacy: .public)")
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        window.title = "A · \(label) – \(title)"
    }
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        term.feed(text: "\r\n[Prototyp] Prozess beendet, Code \(exitCode.map(String.init) ?? "Signal")\r\n")
        log.info("Weg A beendet: \(exitCode ?? -1, privacy: .public)")
    }
    func windowWillClose(_ notification: Notification) {
        term.terminate()
        Sessions.shared.remove(self)
    }
}

// MARK: - Weg B: posix_spawn mit eigener PTY (Kandidat für M1)

/// Nur ausdrücklich genannte Deskriptoren gehen ans Kind (POSIX_SPAWN_CLOEXEC_DEFAULT),
/// das Passwort liegt immer auf fd 3. OSC 52 (Zwischenablage) lesen/schreiben ist abgelehnt.
@MainActor
final class SpawnSession: NSObject, TerminalViewDelegate, NSWindowDelegate {
    let window: NSWindow
    let term: TerminalView
    let label: String
    private var master: Int32 = -1
    private var pid: pid_t = 0
    private var readSource: DispatchSourceRead?
    private var exitSource: DispatchSourceProcess?

    init(label: String) {
        self.label = label
        term = TerminalView(frame: NSRect(x: 0, y: 0, width: 820, height: 500))
        window = NSWindow(contentRect: term.frame, styleMask: [.titled, .closable, .resizable, .miniaturizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "B · \(label)"
        window.contentView = term
        window.isReleasedWhenClosed = false
        window.delegate = self
        term.terminalDelegate = self
    }

    /// extraFDs: (Quelle im Elternprozess, Ziel im Kind). Quellen werden danach geschlossen.
    func start(executable: String, args: [String], extraFDs: [(Int32, Int32)] = []) throws {
        // Alle Quellen und Kopien werden in jedem Fall geschlossen – auch wenn unten etwas wirft
        defer { for (source, _) in extraFDs { close(source) } }
        var mapped: [(Int32, Int32)] = []
        defer { for (high, _) in mapped { close(high) } }
        // Quellen über fd 10 legen, damit dup2 auf 3/4 keine andere Quelle überschreibt
        for (source, target) in extraFDs {
            let high: Int32 = fcntl(source, F_DUPFD_CLOEXEC, 10)
            guard high >= 0 else { throw PrototypeError("dup: errno \(errno)") }
            mapped.append((high, target))
        }
        let env: [String] = try childEnvironment()

        let m: Int32 = posix_openpt(O_RDWR | O_NOCTTY)
        guard m >= 0 else { throw PrototypeError("PTY nicht verfügbar: errno \(errno)") }
        var keepMaster: Bool = false
        defer { if !keepMaster { close(m) } }
        guard grantpt(m) == 0, unlockpt(m) == 0, let namePointer = ptsname(m) else {
            throw PrototypeError("PTY nicht verfügbar: errno \(errno)")
        }
        _ = fcntl(m, F_SETFD, FD_CLOEXEC)
        // Slave im Elternprozess öffnen und offen halten: Die Größe wird erst gesetzt, wenn der Slave offen ist,
        // und das Kind bekommt genau diese Datei (kein zweites Öffnen über den Pfad).
        let slave: Int32 = open(namePointer, O_RDWR | O_NOCTTY | O_CLOEXEC)
        guard slave >= 0 else { throw PrototypeError("PTY-Slave: errno \(errno)") }
        defer { close(slave) }
        let dims = term.terminalDimensions
        var size = winsize(ws_row: UInt16(dims.rows > 0 ? dims.rows : 24), ws_col: UInt16(dims.cols > 0 ? dims.cols : 80),
                           ws_xpixel: 0, ws_ypixel: 0)
        // Die App Sandbox verweigert TIOCSWINSZ auf /dev/ttys* („deny file-ioctl … (_IO "t" 103)“), auf dem
        // Master (/dev/ptmx) ist es erlaubt. Falls es trotzdem scheitert: nur warnen und weitermachen.
        var sizeWarning: String? = nil
        if ioctl(m, TIOCSWINSZ, &size) != 0 { sizeWarning = "TIOCSWINSZ verweigert (errno \(errno))" }
        // Sandbox verweigert plink tcsetattr auf /dev/ttys* („deny file-ioctl … (_IO "t" 20)“) – plink kann den
        // Rohmodus nicht setzen. Messversuch: Die App setzt ihn vorab über den Master (ptmx ist erlaubt).
        if inSandbox {
            var mode = termios()
            if tcgetattr(m, &mode) == 0 {
                cfmakeraw(&mode)
                if tcsetattr(m, TCSANOW, &mode) != 0 { sizeWarning = (sizeWarning ?? "") + " · Rohmodus verweigert (errno \(errno))" }
            } else {
                sizeWarning = (sizeWarning ?? "") + " · tcgetattr verweigert (errno \(errno))"
            }
        }
        log.info("Weg B Startgröße \(size.ws_col, privacy: .public)x\(size.ws_row, privacy: .public) (gemeldet \(dims.cols, privacy: .public)x\(dims.rows, privacy: .public))")

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_adddup2(&actions, slave, 0)
        posix_spawn_file_actions_adddup2(&actions, slave, 1)
        posix_spawn_file_actions_adddup2(&actions, slave, 2)
        for (high, target) in mapped { posix_spawn_file_actions_adddup2(&actions, high, target) }

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        let flags: Int32 = POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK
        posix_spawnattr_setflags(&attributes, Int16(flags))
        var allSignals = sigset_t()
        sigfillset(&allSignals)
        posix_spawnattr_setsigdefault(&attributes, &allSignals)
        var noSignals = sigset_t()
        sigemptyset(&noSignals)
        posix_spawnattr_setsigmask(&attributes, &noSignals)

        let argv: [UnsafeMutablePointer<CChar>?] = ([executable] + args).map { strdup($0) } + [nil]
        let envp: [UnsafeMutablePointer<CChar>?] = env.map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }
        var child: pid_t = 0
        let rc: Int32 = posix_spawn(&child, executable, &actions, &attributes, argv, envp)
        guard rc == 0 else { throw PrototypeError("posix_spawn: \(rc)") }
        keepMaster = true
        master = m
        pid = child

        term.feed(text: "[Prototyp] Weg B (posix_spawn) · Sandbox: \(inSandbox ? "ja" : "nein") · \(label)\r\n")
        term.feed(text: "[Prototyp] \(executable.split(separator: "/").last ?? "") \(args.joined(separator: " "))\r\n")
        if let warning = sizeWarning { term.feed(text: "[Prototyp] WARNUNG: \(warning)\r\n") }
        term.feed(text: "\r\n")
        window.center()
        window.makeKeyAndOrderFront(nil)
        startReading()
        log.info("Weg B gestartet: \(self.label, privacy: .public)")
    }

    private func startReading() {
        let fd: Int32 = master
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 65536)
            let n: Int = read(fd, &buffer, buffer.count)
            MainActor.assumeIsolated {
                if n > 0 {
                    self?.term.feed(byteArray: buffer[0..<n])
                } else {
                    self?.master = -1   // fd wird gleich geschlossen und kann neu vergeben werden
                    self?.readSource?.cancel()
                }
            }
        }
        source.setCancelHandler { close(fd) }
        readSource = source
        source.resume()

        let childPID: pid_t = pid
        let exit = DispatchSource.makeProcessSource(identifier: childPID, eventMask: .exit, queue: .main)
        exit.setEventHandler { [weak self] in
            var status: Int32 = 0
            waitpid(childPID, &status, 0)
            MainActor.assumeIsolated {
                self?.pid = 0   // abgeholt – PID darf nicht mehr signalisiert werden
                self?.term.feed(text: "\r\n[Prototyp] Prozess beendet, Rohstatus \(status)\r\n")
                self?.exitSource?.cancel()
            }
            log.info("Weg B beendet: \(status, privacy: .public)")
        }
        exitSource = exit
        exit.resume()
    }

    // TerminalViewDelegate
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        guard master >= 0 else { return }
        data.withUnsafeBytes { raw in
            var offset: Int = 0
            while offset < raw.count {
                let n: Int = write(master, raw.baseAddress! + offset, raw.count - offset)
                if n <= 0 { break }
                offset += n
            }
        }
    }
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        guard master >= 0 else { return }
        var size = winsize(ws_row: UInt16(newRows), ws_col: UInt16(newCols), ws_xpixel: 0, ws_ypixel: 0)
        if PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: master, windowSize: &size) != 0 {
            log.error("Weg B: TIOCSWINSZ bei Größenänderung verweigert, errno \(errno, privacy: .public)")
        }
        // XNU führt die Datei-Aktionen vor setsid aus: plink hat kein Steuerterminal, also bekommt es
        // SIGWINCH nicht vom Kernel. plink liest die Größe danach selbst per TIOCGWINSZ von stdin.
        if pid > 0 { kill(pid, SIGWINCH) }
    }
    func setTerminalTitle(source: TerminalView, title: String) { window.title = "B · \(label) – \(title)" }
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func scrolled(source: TerminalView, position: Double) {}
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    func clipboardCopy(source: TerminalView, content: Data) {
        term.feed(text: "\r\n[Prototyp] OSC 52 Schreiben in die Zwischenablage abgelehnt (S11)\r\n")
    }
    func clipboardRead(source: TerminalView) -> Data? {
        term.feed(text: "\r\n[Prototyp] OSC 52 Lesen der Zwischenablage abgelehnt (S11)\r\n")
        return nil
    }
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        term.feed(text: "\r\n[Prototyp] Link nicht geöffnet (S11)\r\n")
    }

    func windowWillClose(_ notification: Notification) {
        if pid > 0 { kill(pid, SIGHUP) }
        readSource?.cancel()
        Sessions.shared.remove(self)
    }
}

// MARK: - Fensterverwaltung und Menü

@MainActor
final class Sessions {
    static let shared = Sessions()
    private var open: [NSObject] = []
    func add(_ session: NSObject) { open.append(session) }
    func remove(_ session: NSObject) { open.removeAll { $0 === session } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        showEnvironment(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Prototyp beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Bearbeiten")
        edit.addItem(withTitle: "Kopieren", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Einsetzen", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Alles auswählen", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let testItem = NSMenuItem()
        let test = NSMenu(title: "Test")
        let entries: [(String, Selector)] = [
            ("1 · Verbinden (A, forkpty)", #selector(connectA(_:))),
            ("2 · Verbinden (B, posix_spawn)", #selector(connectB(_:))),
            ("3 · Verbinden mit Schlüsselbund-Passwort (A, fd beliebig)", #selector(passwordA(_:))),
            ("4 · Verbinden mit Schlüsselbund-Passwort (B, fd 3)", #selector(passwordB(_:))),
            ("5 · Schlüsseldatei direkt (Öffnen-Dialog → -i Pfad)…", #selector(keyDirect(_:))),
            ("6 · Schlüsseldatei als Kopie im App-Ordner…", #selector(keyCopy(_:))),
            ("7 · Serielles Gerät öffnen…", #selector(serial(_:))),
            ("8 · Umgebung des Kindprozesses anzeigen", #selector(showEnvironment(_:))),
            ("-", #selector(showEnvironment(_:))),
            ("Testpasswort im Schlüsselbund ablegen…", #selector(storePassword(_:))),
            ("Testpasswort aus dem Schlüsselbund löschen", #selector(deletePassword(_:)))
        ]
        for (title, action) in entries {
            if title == "-" { test.addItem(.separator()); continue }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            test.addItem(item)
        }
        testItem.submenu = test
        main.addItem(testItem)
        NSApp.mainMenu = main
    }

    private func run(_ body: () throws -> Void) {
        do { try body() } catch {
            let alert = NSAlert()
            alert.messageText = "Test fehlgeschlagen"
            alert.informativeText = "\(error)"
            alert.runModal()
        }
    }

    private func startA(_ label: String, _ executable: String, _ args: [String], fd: Int32? = nil) throws {
        let session = ForkptySession(label: label)
        try session.start(executable: executable, args: args, inheritedFD: fd)
        Sessions.shared.add(session)
    }

    private func startB(_ label: String, _ args: [String], extra: [(Int32, Int32)] = []) throws {
        let session = SpawnSession(label: label)
        try session.start(executable: plinkPath(), args: args, extraFDs: extra)
        Sessions.shared.add(session)
    }

    @objc func connectA(_ sender: Any?) { run { try startA("localhost", plinkPath(), ["-ssh", try localTarget()]) } }
    @objc func connectB(_ sender: Any?) { run { try startB("localhost", ["-ssh", try localTarget()]) } }

    @objc func passwordA(_ sender: Any?) {
        run {
            let target: String = try localTarget()   // vor der Pipe: nichts darf zwischen Pipe und Start werfen
            let fd: Int32 = try secretPipe(try loadTestPassword(), inheritable: true)
            try startA("Passwort über /dev/fd/\(fd)", plinkPath(),
                       ["-ssh", "-pwfile", "/dev/fd/\(fd)", target], fd: fd)
        }
    }

    @objc func passwordB(_ sender: Any?) {
        run {
            let target: String = try localTarget()
            let fd: Int32 = try secretPipe(try loadTestPassword(), inheritable: false)
            try startB("Passwort über /dev/fd/3", ["-ssh", "-pwfile", "/dev/fd/3", target], extra: [(fd, 3)])
        }
    }

    private func chooseFile() -> URL? {
        let panel = NSOpenPanel()
        panel.message = "Privaten Schlüssel (.ppk) wählen"
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    @objc func keyDirect(_ sender: Any?) {
        guard let url = chooseFile() else { return }
        run { try startA("Schlüssel direkt", plinkPath(), ["-ssh", "-i", url.path, try localTarget()]) }
    }

    @objc func keyCopy(_ sender: Any?) {
        guard let url = chooseFile() else { return }
        run {
            let copy: URL = try supportDirectory("keys").appendingPathComponent("test-key.ppk")
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: url, to: copy)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: copy.path)
            try startA("Schlüssel-Kopie im App-Ordner", plinkPath(), ["-ssh", "-i", copy.path, try localTarget()])
        }
    }

    @objc func serial(_ sender: Any?) {
        let devices: [String] = ((try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? [])
            .filter { $0.hasPrefix("cu.") }.sorted()
        guard !devices.isEmpty else {
            run { throw PrototypeError("Kein /dev/cu.* gefunden") }
            return
        }
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 26))
        popup.addItems(withTitles: devices)
        let alert = NSAlert()
        alert.messageText = "Serielles Gerät öffnen (115200 8N1)"
        alert.informativeText = "Nur Öffnen wird geprüft; ohne angeschlossenes Gerät kommt keine Ausgabe."
        alert.accessoryView = popup
        alert.addButton(withTitle: "Öffnen")
        alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn, let name = popup.titleOfSelectedItem else { return }
        run { try startA("Seriell", plinkPath(), ["-serial", "/dev/\(name)", "-sercfg", "115200,8,n,1,N"]) }
    }

    @objc func showEnvironment(_ sender: Any?) {
        run { try startA("Umgebung", "/usr/bin/env", []) }
    }

    @objc func storePassword(_ sender: Any?) {
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        let alert = NSAlert()
        alert.messageText = "Testpasswort ablegen"
        alert.informativeText = "Passwort deines Mac-Benutzers für die SSH-Anmeldung an localhost. Es wird nur im Schlüsselbund gespeichert (Dienst „\(keychainService)“) und nach M0 gelöscht."
        alert.accessoryView = field
        alert.addButton(withTitle: "Sichern")
        alert.addButton(withTitle: "Abbrechen")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        run { try storeTestPassword(field.stringValue) }
        field.stringValue = ""
    }

    @objc func deletePassword(_ sender: Any?) {
        let status: OSStatus = SecItemDelete(keychainQuery() as CFDictionary)
        let alert = NSAlert()
        alert.messageText = status == errSecSuccess ? "Testeintrag gelöscht" : "Kein Testeintrag gelöscht (Status \(status))"
        alert.runModal()
    }
}

// Top-Level-Code ist im Swift-5-Modus nicht MainActor-isoliert
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let appDelegate = AppDelegate()   // lebt weiter, weil run() nicht zurückkehrt
    app.delegate = appDelegate
    app.run()
}
