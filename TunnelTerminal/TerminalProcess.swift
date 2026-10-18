import Darwin
import Foundation

/// Startet ein Programm an einem eigenen Pseudo-Terminal (Weg B aus M0, Plan S8).
///
/// - `posix_spawn` mit `POSIX_SPAWN_CLOEXEC_DEFAULT`: das Kind erbt nur 0/1/2 (keine Deskriptoren der App).
/// - Die App öffnet die Slave-Seite selbst (`O_NOCTTY`) und setzt die Größe über den Master, solange der Slave
///   offen ist (M0, B13). Das Kind hat dadurch kein Steuerterminal und bekommt `SIGWINCH` von der App.
/// - Neue Dateien des Kindes entstehen mit `0600` (umask 077), z. B. plinks `sshhostkeys`.
/// - Solange das Kind läuft, hält sich das Objekt über seine Ereignisquellen selbst am Leben; nach dem Ende
///   (Kind abgeholt, Ausgabe gelesen) meldet es `onExit` mit dem `waitpid`-Status.
final class TerminalProcess {
    struct Failure: Error {
        let message: String
    }

    var onOutput: ((ArraySlice<UInt8>) -> Void)?
    var onExit: ((Int32) -> Void)?

    /// Obergrenze für Eingaben, die das Programm noch nicht gelesen hat (großes Einfügen, Antworten auf Abfragen).
    static let pendingLimit: Int = 4 << 20
    private static let chunk: Int = 65_536

    private var pid: pid_t = 0
    private var master: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var writeSource: DispatchSourceWrite?
    private var exitSource: DispatchSourceProcess?
    private var buffer: [UInt8] = [UInt8](repeating: 0, count: TerminalProcess.chunk)
    private var pending: [UInt8] = []
    private var sent: Int = 0   // schon geschriebener Anfang von `pending`

    var isRunning: Bool { pid > 0 }

    func start(executable: String, arguments: [String], environment: [String], columns: Int, rows: Int) throws(Failure) {
        guard pid == 0, master < 0 else { throw Failure(message: "Der Prozess läuft bereits.") }
        let newMaster: Int32 = posix_openpt(O_RDWR | O_NOCTTY)
        guard newMaster >= 0 else { throw Self.failure("Kein Pseudo-Terminal verfügbar") }
        var keepMaster: Bool = false
        defer { if !keepMaster { close(newMaster) } }
        _ = fcntl(newMaster, F_SETFD, FD_CLOEXEC)
        // Nie blockieren: ein Programm, das nicht liest, darf die App nicht anhalten (auch kein Server per Abfrage-Flut)
        _ = fcntl(newMaster, F_SETFL, fcntl(newMaster, F_GETFL) | O_NONBLOCK)
        guard grantpt(newMaster) == 0, unlockpt(newMaster) == 0, let slaveName = ptsname(newMaster) else {
            throw Self.failure("Pseudo-Terminal nicht nutzbar")
        }
        let slave: Int32 = open(slaveName, O_RDWR | O_NOCTTY | O_CLOEXEC)
        guard slave >= 0 else { throw Self.failure("Pseudo-Terminal nicht nutzbar") }
        defer { close(slave) }
        var size: winsize = Self.windowSize(columns: columns, rows: rows)
        _ = ioctl(newMaster, TIOCSWINSZ, &size)

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        for target: Int32 in 0...2 { posix_spawn_file_actions_adddup2(&actions, slave, target) }

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        let flags: Int32 = POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK
        posix_spawnattr_setflags(&attributes, Int16(flags))
        var allSignals: sigset_t = sigset_t()
        sigfillset(&allSignals)
        posix_spawnattr_setsigdefault(&attributes, &allSignals)
        var noSignals: sigset_t = sigset_t()
        sigemptyset(&noSignals)
        posix_spawnattr_setsigmask(&attributes, &noSignals)

        let argv: [UnsafeMutablePointer<CChar>?] = ([executable] + arguments).map { strdup($0) } + [nil]
        let envp: [UnsafeMutablePointer<CChar>?] = environment.map { strdup($0) } + [nil]
        defer {
            argv.forEach { free($0) }
            envp.forEach { free($0) }
        }
        var child: pid_t = 0
        // umask gilt prozessweit; der kurze Moment macht höchstens Dateien der App strenger
        let previousMask: mode_t = umask(0o077)
        let result: Int32 = posix_spawn(&child, executable, &actions, &attributes, argv, envp)
        umask(previousMask)
        guard result == 0 else { throw Failure(message: "Start fehlgeschlagen: \(String(cString: strerror(result)))") }

        keepMaster = true
        master = newMaster
        pid = child
        watch()
    }

    /// Tastatur und Einfügen an das Programm. Blockiert nie: was das Programm gerade nicht annimmt, wartet in
    /// `pending` und geht nach, sobald das Terminal wieder Platz hat. Über `pendingLimit` hinaus wird verworfen.
    func send(_ data: ArraySlice<UInt8>) {
        guard master >= 0, !data.isEmpty else { return }
        if sent >= Self.chunk {
            pending.removeFirst(sent)
            sent = 0
        }
        let room: Int = Self.pendingLimit - (pending.count - sent)
        guard room > 0 else { return }
        pending.append(contentsOf: data.prefix(room))
        flush()
    }

    /// Neue Fenstergröße. Ohne Steuerterminal schickt der Kernel kein `SIGWINCH`, also die App selbst.
    func resize(columns: Int, rows: Int) {
        guard master >= 0 else { return }
        var size: winsize = Self.windowSize(columns: columns, rows: rows)
        _ = ioctl(master, TIOCSWINSZ, &size)
        if pid > 0 { kill(pid, SIGWINCH) }
    }

    /// Beendet das Programm wie ein geschlossenes Terminal (auch der Weg, plinks lokale Abfragen abzubrechen:
    /// Ctrl-C wirkt ohne Steuerterminal nicht, M0 B4).
    func hangUp() {
        if pid > 0 { kill(pid, SIGHUP) }
    }

    /// Lesbarer Text zu einem `waitpid`-Status.
    static func describe(status: Int32) -> String {
        let signal: Int32 = status & 0x7F
        if signal == 0 {
            let code: Int32 = (status >> 8) & 0xFF
            return code == 0 ? "Verbindung beendet." : "Verbindung beendet (Exit-Code \(code))."
        }
        return "Verbindung beendet (Signal \(signal))."
    }

    private func watch() {
        let reader: DispatchSourceRead = DispatchSource.makeReadSource(fileDescriptor: master, queue: .main)
        let descriptor: Int32 = master
        reader.setEventHandler { [self] in
            MainActor.assumeIsolated { _ = self.readOnce() }
        }
        reader.setCancelHandler { close(descriptor) }
        readSource = reader
        reader.resume()

        let child: pid_t = pid
        let exitWatcher: DispatchSourceProcess = DispatchSource.makeProcessSource(identifier: child, eventMask: .exit,
                                                                                   queue: .main)
        exitWatcher.setEventHandler { [self] in
            MainActor.assumeIsolated { self.childExited() }
        }
        exitSource = exitWatcher
        exitWatcher.resume()
    }

    /// Liest einen Block Ausgabe; `false`, wenn gerade nichts da ist oder das Terminal zu ist.
    private func readOnce() -> Bool {
        while master >= 0 {
            let count: Int = read(master, &buffer, Self.chunk)
            if count > 0 {
                onOutput?(buffer[0..<count])
                return true
            }
            if count < 0 && errno == EINTR { continue }
            if count < 0 && errno == EAGAIN { return false }
            closeMaster()   // EOF/EIO: Slave-Seite ist zu
        }
        return false
    }

    /// Schreibt aus `pending`, bis alles weg ist oder das Terminal voll ist (dann weiter über die Schreibquelle).
    private func flush() {
        while master >= 0 && sent < pending.count {
            let written: Int = pending.withUnsafeBytes { write(master, $0.baseAddress! + sent, $0.count - sent) }
            if written > 0 {
                sent += written
            } else if written < 0 && errno == EINTR {
                continue
            } else if written < 0 && errno == EAGAIN {
                waitUntilWritable()
                return
            } else {
                break   // Terminal zu: niemand liest mehr
            }
        }
        pending.removeAll()
        sent = 0
        writeSource?.cancel()
        writeSource = nil
    }

    private func waitUntilWritable() {
        guard writeSource == nil else { return }
        // Eigene Nummer für die Quelle: sie schließt sie selbst, unabhängig vom Ende der Lesequelle
        let descriptor: Int32 = fcntl(master, F_DUPFD_CLOEXEC, 0)
        guard descriptor >= 0 else {
            pending.removeAll()
            sent = 0
            return
        }
        let writer: DispatchSourceWrite = DispatchSource.makeWriteSource(fileDescriptor: descriptor, queue: .main)
        writer.setEventHandler { [self] in
            MainActor.assumeIsolated { self.flush() }
        }
        writer.setCancelHandler { close(descriptor) }
        writeSource = writer
        writer.resume()
    }

    private func childExited() {
        var status: Int32 = 0
        while waitpid(pid, &status, 0) < 0 && errno == EINTR {}
        pid = 0   // abgeholt: die Nummer darf nicht mehr signalisiert werden
        exitSource?.cancel()
        exitSource = nil
        // Rest der Ausgabe lesen, damit die letzte Meldung (z. B. „FATAL ERROR“) vor dem Hinweis steht
        while readOnce() {}
        closeMaster()
        let handler: ((Int32) -> Void)? = onExit
        onExit = nil
        onOutput = nil
        handler?(status)
    }

    private func closeMaster() {
        master = -1   // der Deskriptor wird im Cancel-Handler geschlossen und darf danach neu vergeben werden
        pending.removeAll()
        sent = 0
        writeSource?.cancel()
        writeSource = nil
        readSource?.cancel()
        readSource = nil
    }

    private static func windowSize(columns: Int, rows: Int) -> winsize {
        let safeColumns: UInt16 = UInt16(clamping: columns > 0 ? columns : 80)
        let safeRows: UInt16 = UInt16(clamping: rows > 0 ? rows : 24)
        return winsize(ws_row: safeRows, ws_col: safeColumns, ws_xpixel: 0, ws_ypixel: 0)
    }

    private static func failure(_ text: String) -> Failure {
        Failure(message: "\(text): \(String(cString: strerror(errno)))")
    }
}
