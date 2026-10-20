import AppKit
import Darwin
import TunnelTerminalCore
import XCTest
@testable import TunnelTerminal

/// M6: Ablauf der Dateiübertragung mit einem nachgebauten pscp (Shell-Skript, liest seine Rolle aus dem PuTTY-Ordner
/// des Tests): Teildatei und Ersetzen erst nach Erfolg, Abbrechen, Überschreiben-Rückfrage, Benutzer, Passwort über
/// fd 3, Rückfrage bei gefährlichen Sitzungen (S4). Das echte pscp ist in docs/M6-Machbarkeit.md gemessen.
@MainActor
final class FileTransferTests: XCTestCase {
    private var folder: URL!
    private var directory: PuTTYDirectory!
    private var fake: URL!

    /// Nachgebautes pscp: protokolliert Aufrufe und die geladene Sitzung; Rolle aus `modus`, Ordnerinhalt aus `inhalt`.
    private static let script: String = """
        #!/bin/sh
        PATH=/bin:/usr/bin
        d="$PUTTYDIR"
        printf '%s\\n' "$*" >> "$d/aufrufe"
        cp "$d/sessions/$2" "$d/letzte-sitzung"
        last=""; for a in "$@"; do last="$a"; done
        modus=$(cat "$d/modus" 2>/dev/null)
        case " $* " in *" -ls "*) printf 'Listing directory x\\r\\n'; cat "$d/inhalt" 2>/dev/null; exit 0 ;; esac
        case "$modus" in
          fehler) printf 'pscp: unable to open x: permission denied\\r\\n'; exit 1 ;;
          langsam) printf '\\rdatei                     | 4 kB |   4.0 kB/s | ETA: 00:00:09 |  10%%'; echo teil > "$last"; exec sleep 30 ;;
          passwort)
            case " $* " in
              *" -pwfile /dev/fd/3 "*) IFS= read -r wert <&3; printf '%s' "$wert" > "$d/fd3" ;;
              *) printf 'FATAL ERROR: Cannot answer interactive prompts in batch mode\\r\\n'; exit 1 ;;
            esac ;;
        esac
        printf '\\rdatei                     | 4 kB |   4.0 kB/s | ETA: 00:00:00 | 100%%\\r\\n'
        case "$last" in /*) echo neu > "$last"; chmod 755 "$last" ;; esac
        exit 0
        """

    override func setUp() async throws {
        let base: URL = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTerminalTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        folder = base
        directory = try PuTTYDirectory(url: base.appendingPathComponent("putty", isDirectory: true))
        fake = base.appendingPathComponent("pscp")
        try Self.script.write(to: fake, atomically: true, encoding: .utf8)
        XCTAssertEqual(chmod(fake.path, 0o700), 0)
        var file: SessionFile = SessionFile()
        try file.setHostName("server.example")
        try file.setUserName("test")
        try directory.write(file, sessionName: "Server")
    }

    private func controller(session: String = "Server", prompts: TransferPrompts? = nil) throws -> FileTransferController {
        let folder: PuTTYDirectory = directory
        let connection: Connection = try Connection(savedSession: session, puttyDirectory: { folder }, passwords: nil)
        let transfers: FileTransferController = FileTransferController(pscpPath: fake.path)
        transfers.connection = { connection }
        transfers.prompts = prompts ?? TransferPrompts(password: { _, _ in nil }, replace: { _ in false }, dangers: { _, _ in false })
        return transfers
    }

    private func role(_ name: String) throws {
        try name.write(to: directory.url.appendingPathComponent("modus"), atomically: true, encoding: .utf8)
    }

    private func calls() -> [String] {
        let text: String = (try? String(contentsOf: directory.url.appendingPathComponent("aufrufe"), encoding: .utf8)) ?? ""
        return text.split(separator: "\n").map(String.init)
    }

    /// Teildateien im Testordner und vorübergehende Sitzungen – nach jeder Übertragung keine.
    private func leftovers() throws -> [String] {
        let parts: [String] = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".teil") }
        return parts + directory.sessionNames().filter { $0.hasPrefix(AppIdentity.quickSessionPrefix) }
    }

    private func localFile(_ name: String, _ text: String = "alt") throws -> URL {
        let url: URL = folder.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testDownloadReplacesFileOnlyAfterSuccess() async throws {
        let target: URL = try localFile("bericht.txt")
        let transfers: FileTransferController = try controller()
        await transfers.performDownload(try RemotePath("~/bericht.txt"), to: target, user: nil)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "neu\n")
        XCTAssertEqual(transfers.model.result, "„bericht.txt“ geladen.")
        XCTAssertFalse(transfers.model.resultIsError)
        XCTAssertEqual(transfers.model.downloaded, target)
        XCTAssertFalse(transfers.isRunning)
        XCTAssertEqual(try leftovers(), [])
        let call: String = try XCTUnwrap(calls().last)
        XCTAssertTrue(call.hasPrefix("-load \(AppIdentity.quickSessionPrefix)"), call)
        XCTAssertTrue(call.contains(" -sftp -batch server.example:bericht.txt \(folder.path)/.\(AppIdentity.name)-"), call)
        XCTAssertGreaterThan(getxattr(target.path, "com.apple.quarantine", nil, 0, 0, 0), 0, "wie ein Download markiert")
        let mode: Int = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions] as? Int)
        XCTAssertEqual(mode, 0o600, "nicht ausführbar, auch wenn pscp die Rechte vom Server übernimmt")
    }

    func testCancelledDownloadKeepsOldFile() async throws {
        try role("langsam")
        let target: URL = try localFile("gross.bin")
        let transfers: FileTransferController = try controller()
        let path: RemotePath = try RemotePath("gross.bin")
        let running: Task<Void, Never> = Task { await transfers.performDownload(path, to: target, user: nil) }
        var waited: Int = 0
        while try leftovers().allSatisfy({ !$0.hasSuffix(".teil") }), waited < 100 {
            try await Task.sleep(for: .milliseconds(50))
            waited += 1
        }
        XCTAssertTrue(transfers.isRunning)
        XCTAssertEqual(transfers.model.fraction, 0.1, "Fortschritt aus der Ausgabe von pscp")
        transfers.cancel()
        await running.value
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "alt")
        XCTAssertEqual(try leftovers(), [])
        XCTAssertEqual(transfers.model.result, "Abgebrochen – auf dem Mac ist nichts geändert.")
        XCTAssertNil(transfers.model.activity)
    }

    func testFailedDownloadReportsAndKeepsOldFile() async throws {
        try role("fehler")
        let target: URL = try localFile("x.txt")
        let transfers: FileTransferController = try controller()
        await transfers.performDownload(try RemotePath("x.txt"), to: target, user: nil)
        XCTAssertEqual(transfers.model.result, "Nicht geladen: unable to open x: permission denied")
        XCTAssertTrue(transfers.model.resultIsError)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "alt")
        XCTAssertEqual(try leftovers(), [])
    }

    func testUploadAsksBeforeReplacing() async throws {
        try "-rw-r--r--    1 test staff          13 Oct 20 18:13 a.txt\r\n"
            .write(to: directory.url.appendingPathComponent("inhalt"), atomically: true, encoding: .utf8)
        let file: URL = try localFile("a.txt")
        var asked: [[String]] = []
        var answer: Bool = false
        let transfers: FileTransferController = try controller(prompts: TransferPrompts(
            password: { _, _ in nil }, replace: { names in asked.append(names); return answer }, dangers: { _, _ in false }))
        await transfers.performUpload([file], to: try RemotePath("www"), user: nil)
        XCTAssertEqual(asked, [["a.txt"]])
        XCTAssertEqual(calls().count, 1, "nur aufgelistet, nichts hochgeladen")
        XCTAssertEqual(transfers.model.result, "Nicht hochgeladen.")
        answer = true
        await transfers.performUpload([file], to: try RemotePath("www"), user: nil)
        XCTAssertEqual(calls().count, 3)
        XCTAssertTrue(calls()[1].hasSuffix("-sftp -batch -q -ls server.example:www"), calls()[1])
        XCTAssertTrue(calls()[2].hasSuffix("-sftp -batch \(file.path) server.example:www"), calls()[2])
        XCTAssertEqual(transfers.model.result, "„a.txt“ hochgeladen nach „www“.")
        XCTAssertEqual(try leftovers(), [])
    }

    /// Regressionstest (Code-Review M6): Eine lange Auflistung darf nicht abgeschnitten werden, sonst fehlten Namen vorn und
    /// pscp überschriebe still.
    func testLongListingStillFindsExistingFile() async throws {
        let others: String = (0..<2_000).map { "-rw-r--r--    1 test staff          13 Oct 20 18:13 andere-\($0).txt\r\n" }.joined()
        try ("-rw-r--r--    1 test staff          13 Oct 20 18:13 a.txt\r\n" + others)
            .write(to: directory.url.appendingPathComponent("inhalt"), atomically: true, encoding: .utf8)
        var asked: [[String]] = []
        let transfers: FileTransferController = try controller(prompts: TransferPrompts(
            password: { _, _ in nil }, replace: { names in asked.append(names); return false }, dangers: { _, _ in false }))
        await transfers.performUpload([try localFile("a.txt"), try localFile("neu.txt")], to: try RemotePath("www"), user: nil)
        XCTAssertEqual(asked, [["a.txt"]])
    }

    func testTwoFilesWithTheSameNameAreRejected() async throws {
        let first: URL = try localFile("a.txt")
        let other: URL = folder.appendingPathComponent("unter", isDirectory: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let second: URL = other.appendingPathComponent("a.txt")
        try "zwei".write(to: second, atomically: true, encoding: .utf8)
        let transfers: FileTransferController = try controller()
        await transfers.performUpload([first, second], to: try RemotePath(""), user: nil)
        XCTAssertEqual(transfers.model.result, "Nicht hochgeladen: Zwei Dateien heißen „a.txt“ – bitte einzeln hochladen.")
        // ein Mac als Server unterscheidet Groß-/Kleinschreibung nicht (Prüfer M6)
        let shouting: URL = other.appendingPathComponent("A.TXT")
        try FileManager.default.moveItem(at: second, to: shouting)
        await transfers.performUpload([first, shouting], to: try RemotePath(""), user: nil)
        XCTAssertEqual(transfers.model.result, "Nicht hochgeladen: Zwei Dateien heißen „A.TXT“ – bitte einzeln hochladen.")
        XCTAssertEqual(calls(), [])
    }

    func testUploadRejectsFoldersAndBackslashNames() async throws {
        let transfers: FileTransferController = try controller()
        transfers.window = { NSWindow() }
        transfers.upload([folder])
        XCTAssertEqual(transfers.model.result, "„\(folder.lastPathComponent)“ ist keine Datei – Ordner lassen sich nicht hochladen.")
        await transfers.performUpload([try localFile("a\\b.txt")], to: try RemotePath(""), user: nil)
        XCTAssertEqual(transfers.model.result, "Nicht hochgeladen: " + InputError.backslashInName.message)
        XCTAssertEqual(calls(), [], "abgelehnt, bevor pscp startet")
    }

    func testSessionWithoutUserUsesAskedUser() async throws {
        var file: SessionFile = SessionFile()
        try file.setHostName("server.example")
        try directory.write(file, sessionName: "Ohne")
        let transfers: FileTransferController = try controller(session: "Ohne")
        await transfers.performUpload([try localFile("a.txt")], to: try RemotePath(""), user: nil)
        XCTAssertEqual(transfers.model.result, InputError.empty(.user).message)
        XCTAssertEqual(calls(), [], "pscp nähme sonst den Benutzer dieses Macs")
        await transfers.performUpload([try localFile("a.txt")], to: try RemotePath(""), user: "test")
        let session: String = try String(contentsOf: directory.url.appendingPathComponent("letzte-sitzung"), encoding: .utf8)
        XCTAssertTrue(session.contains("UserName=test"), session)
        XCTAssertEqual(transfers.model.result, "„a.txt“ hochgeladen in den persönlichen Ordner.")
    }

    func testPasswordGoesThroughPipeOnlyAfterAsking() async throws {
        try role("passwort")
        var prompts: Int = 0
        let transfers: FileTransferController = try controller(prompts: TransferPrompts(
            password: { target, rejected in
                prompts += 1
                XCTAssertEqual(target, "test@server.example")
                XCTAssertFalse(rejected)
                return "test-wert"
            }, replace: { _ in false }, dangers: { _, _ in false }))
        await transfers.performDownload(try RemotePath("x.txt"), to: folder.appendingPathComponent("x.txt"), user: nil)
        XCTAssertEqual(prompts, 1)
        XCTAssertEqual(try String(contentsOf: directory.url.appendingPathComponent("fd3"), encoding: .utf8), "test-wert")
        XCTAssertFalse(calls().joined().contains("test-wert"), "nie in den Argumenten (S1)")
        XCTAssertEqual(calls().last?.contains("-pwfile /dev/fd/3"), true)
        XCTAssertEqual(transfers.model.result, "„x.txt“ geladen.")
    }

    func testDangerousSessionNeedsConfirmation() async throws {
        var file: SessionFile = SessionFile()
        try file.setHostName("server.example")
        try file.setUserName("test")
        try file.setValue("5", forKey: "ProxyMethod")
        try file.setValue("nc %host %port", forKey: "ProxyTelnetCommand")
        try directory.write(file, sessionName: "Befehl")
        var warned: Int = 0
        let transfers: FileTransferController = try controller(session: "Befehl", prompts: TransferPrompts(
            password: { _, _ in nil }, replace: { _ in false }, dangers: { warnings, _ in warned = warnings.count; return false }))
        await transfers.performUpload([try localFile("a.txt")], to: try RemotePath(""), user: nil)
        XCTAssertGreaterThan(warned, 0)
        XCTAssertEqual(calls(), [], "ohne Zustimmung startet pscp nicht (S4)")
    }

    /// Ende-zu-Ende mit dem eingebauten pscp gegen den Wegwerf-sshd aus M1 (nur über `build/m6/ui.sh e2e`, sonst
    /// übersprungen): Hochladen, Rückfrage vor dem Überschreiben, Herunterladen, Fehler bei fehlender Datei bzw. fehlendem
    /// Zielordner. Server und Mac sind derselbe Rechner, „fern“ ist deshalb ein lokaler Ordner.
    func testRealPscpAgainstTestServer() async throws {
        guard let base = ProcessInfo.processInfo.environment["TUNNELTERMINAL_E2E"] else {
            throw XCTSkip("Nur mit build/m6/ui.sh e2e (braucht den Testserver)")
        }
        let root: URL = URL(fileURLWithPath: base, isDirectory: true)
        let remote: URL = root.appendingPathComponent("fern", isDirectory: true)
        let real: PuTTYDirectory = try PuTTYDirectory(url: root.appendingPathComponent("putty", isDirectory: true))
        let connection: Connection = try Connection(savedSession: "M6/Mac", puttyDirectory: { real }, passwords: nil)
        let transfers: FileTransferController = FileTransferController()   // pscp aus dem App-Paket
        transfers.connection = { connection }
        var asked: [[String]] = []
        transfers.prompts = TransferPrompts(password: { _, _ in nil }, replace: { names in asked.append(names); return false },
                                            dangers: { _, _ in false })
        let source: URL = try localFile("hoch geladen.txt", "Inhalt vom Mac")
        await transfers.performUpload([source], to: try RemotePath(remote.path), user: nil)
        XCTAssertEqual(transfers.model.result, "„hoch geladen.txt“ hochgeladen nach „\(remote.path)“.")
        XCTAssertEqual(try String(contentsOf: remote.appendingPathComponent("hoch geladen.txt"), encoding: .utf8), "Inhalt vom Mac")
        await transfers.performUpload([source], to: try RemotePath(remote.path), user: nil)
        XCTAssertEqual(asked, [["hoch geladen.txt"]])
        XCTAssertEqual(transfers.model.result, "Nicht hochgeladen.")
        // Prüfer M6: ein Mac als Server unterscheidet Groß-/Kleinschreibung nicht; Umlaute in der Ordnerliste von pscp
        let shouting: URL = try localFile("Laut/HOCH GELADEN.TXT", "anders")
        await transfers.performUpload([shouting], to: try RemotePath(remote.path), user: nil)
        let umlaut: URL = try localFile("Grüße.txt", "ä")
        await transfers.performUpload([umlaut], to: try RemotePath(remote.path), user: nil)
        await transfers.performUpload([umlaut], to: try RemotePath(remote.path), user: nil)
        XCTAssertEqual(asked, [["hoch geladen.txt"], ["HOCH GELADEN.TXT"], ["Grüße.txt"]])
        XCTAssertEqual(try String(contentsOf: remote.appendingPathComponent("hoch geladen.txt"), encoding: .utf8), "Inhalt vom Mac")

        let target: URL = folder.appendingPathComponent("zurück.txt")
        await transfers.performDownload(try RemotePath(remote.appendingPathComponent("hoch geladen.txt").path), to: target, user: nil)
        XCTAssertEqual(transfers.model.result, "„zurück.txt“ geladen.")
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "Inhalt vom Mac")
        let program: URL = remote.appendingPathComponent("programm")
        try "#!/bin/sh\n".write(to: program, atomically: true, encoding: .utf8)
        XCTAssertEqual(chmod(program.path, 0o755), 0)
        let fetched: URL = folder.appendingPathComponent("programm")
        await transfers.performDownload(try RemotePath(program.path), to: fetched, user: nil)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: fetched.path)[.posixPermissions] as? Int, 0o600)
        await transfers.performDownload(try RemotePath(remote.appendingPathComponent("fehlt.txt").path), to: target, user: nil)
        XCTAssertEqual(transfers.model.resultIsError, true)
        XCTAssertTrue(transfers.model.result?.contains("no such file") == true, transfers.model.result ?? "")
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "Inhalt vom Mac", "bleibt nach einem Fehler")
        await transfers.performUpload([source], to: try RemotePath(remote.appendingPathComponent("gibt-es-nicht").path), user: nil)
        XCTAssertTrue(transfers.model.result?.hasPrefix("Nicht hochgeladen: Unable to open") == true, transfers.model.result ?? "")
        XCTAssertFalse(FileManager.default.fileExists(atPath: remote.appendingPathComponent("gibt-es-nicht").path),
                       "pscp hätte sonst eine Datei mit dem Ordnernamen angelegt")
        XCTAssertEqual(real.sessionNames().filter { $0.hasPrefix(AppIdentity.quickSessionPrefix) }, [])
        XCTAssertEqual(try leftovers(), [])
    }

    /// Plan 3.1: Symbolleisten-Knopf „Hochladen“, Menübefehle ohne Kürzel; ohne SSH-Verbindung nicht verfügbar.
    func testUploadCommandsInToolbarAndMenu() throws {
        let library: SessionLibrary = SessionLibrary(directory: directory)
        let window: ConnectionWindowController = ConnectionWindowController(library: library, connected: ConnectedSessions())
        addTeardownBlock { @MainActor in window.window?.close() }
        XCTAssertTrue(window.window?.toolbar?.items.contains { $0.itemIdentifier == WorkbenchToolbar.upload } == true)
        let connectionMenu: NSMenu = try XCTUnwrap(MainMenu.build().items.first { $0.title == "Verbindung" }?.submenu)
        for action in [#selector(ConnectionWindowController.uploadFiles(_:)), #selector(ConnectionWindowController.downloadFile(_:)),
                       #selector(ConnectionWindowController.cancelTransfer(_:))] {
            let item: NSMenuItem = try XCTUnwrap(connectionMenu.items.first { $0.action == action }, "\(action)")
            XCTAssertEqual(item.keyEquivalent, "")
            XCTAssertFalse(window.validateMenuItem(item), "ohne SSH-Verbindung bzw. ohne laufende Übertragung")
        }
    }
}
