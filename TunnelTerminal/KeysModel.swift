import AppKit
import Observation
import TunnelTerminalCore

/// Zustand des Fensters „Schlüssel“ (Plan M3): neuen Schlüssel mit puttygen erzeugen, Schlüsseldatei öffnen,
/// öffentlichen Teil und Fingerabdruck zeigen, zwischen .ppk und OpenSSH umwandeln. Passphrasen gehen nur über
/// Pipes an puttygen (S1) und bleiben nicht im Modell.
@Observable
final class KeysModel {
    /// Geöffneter Schlüssel: Datei, öffentlicher Teil (OpenSSH-Zeile) und SHA256-Fingerabdruck.
    struct LoadedKey: Equatable {
        let url: URL
        let publicKey: String
        let fingerprint: String
    }

    /// Wofür puttygen eine Passphrase braucht.
    enum PendingAction: Equatable {
        case load(URL)
        case convert(URL, KeyFormat, URL)
    }

    /// Abfrage der Passphrase als Sheet.
    struct PassphraseRequest: Identifiable {
        let id: UUID = UUID()
        let action: PendingAction
        let wasWrong: Bool
    }

    var key: LoadedKey?
    var message: String?
    var isWorking: Bool = false
    var passphraseRequest: PassphraseRequest?

    // Neuer Schlüssel
    var kind: KeyKind = .standard
    var comment: String = ""
    var passphrase: String = ""
    var repeatedPassphrase: String = ""

    /// Fenster für die Datei-Dialoge (als Sheet, Richtlinien 3.4 Regel 18).
    @ObservationIgnored weak var window: NSWindow?

    private var puttygen: String { HelperProcess.puttygenPath }
    private static var sshFolder: URL { FileManager.default.homeDirectoryForCurrentUser.appending(path: ".ssh", directoryHint: .isDirectory) }

    var passphrasesMatch: Bool { passphrase == repeatedPassphrase }

    // MARK: - Erzeugen

    func generate() {
        guard passphrasesMatch else { return }
        if let problem = Self.passphraseProblem(passphrase) {
            message = problem
            return
        }
        let panel: NSSavePanel = NSSavePanel()
        panel.message = "Wohin soll der neue private Schlüssel (PuTTY-Format)?"
        panel.nameFieldStringValue = "id_\(kind.rawValue).ppk"
        panel.directoryURL = Self.existingSSHFolder
        panel.showsHiddenFiles = true
        panel.canCreateDirectories = true
        run(panel) { [weak self] url in self?.generate(at: url) }
    }

    private func generate(at url: URL) {
        let secret: Data = Data(passphrase.utf8)
        passphrase = ""
        repeatedPassphrase = ""
        let command: PuttygenCommand
        do {
            command = try .generate(kind, comment: comment.trimmingCharacters(in: .whitespaces), output: url.path)
        } catch {
            message = error.message
            return
        }
        work {
            let result: HelperProcess.Result = try await HelperProcess.run(self.puttygen, command.arguments, secrets: [secret])
            guard result.succeeded else { throw KeyFailure(problem: PuttygenCommand.problem(fromErrorOutput: result.output)) }
            try await self.read(url, passphrase: nil)
            self.message = "Neuer Schlüssel gesichert."
        }
    }

    // MARK: - Öffnen und Anzeigen

    func open() {
        guard let window else { return }
        let panel: NSOpenPanel = NSOpenPanel()
        panel.message = "Schlüsseldatei wählen (.ppk oder OpenSSH, z. B. ~/.ssh/id_ed25519)"
        panel.prompt = "Öffnen"
        panel.directoryURL = Self.existingSSHFolder
        panel.showsHiddenFiles = true
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.load(url, passphrase: nil)
        }
    }

    private func load(_ url: URL, passphrase: Data?) {
        work { try await self.read(url, passphrase: passphrase) }
    }

    /// Öffentlicher Teil und Fingerabdruck; verlangt puttygen eine Passphrase, fragt das Fenster danach.
    private func read(_ url: URL, passphrase: Data?) async throws {
        let withPassphrase: Bool = passphrase != nil
        let secrets: [Data] = passphrase.map { [$0] } ?? []
        let publicResult: HelperProcess.Result = try await HelperProcess.run(
            puttygen, try PuttygenCommand.publicKey(of: url.path, withPassphrase: withPassphrase).arguments, secrets: secrets)
        guard publicResult.succeeded, let publicKey = PuttygenCommand.publicKey(fromOutput: publicResult.output) else {
            let problem: PuttygenProblem = PuttygenCommand.problem(fromErrorOutput: publicResult.output)
            if problem == .passphraseNeeded || problem == .wrongPassphrase {
                passphraseRequest = PassphraseRequest(action: .load(url), wasWrong: problem == .wrongPassphrase)
                return
            }
            throw KeyFailure(problem: problem)
        }
        let printResult: HelperProcess.Result = try await HelperProcess.run(
            puttygen, try PuttygenCommand.fingerprint(of: url.path, withPassphrase: withPassphrase).arguments, secrets: secrets)
        guard printResult.succeeded, let fingerprint = PuttygenCommand.fingerprint(fromOutput: printResult.output) else {
            throw KeyFailure(problem: PuttygenCommand.problem(fromErrorOutput: printResult.output))
        }
        key = LoadedKey(url: url, publicKey: publicKey, fingerprint: fingerprint)
        message = nil
    }

    // MARK: - Umwandeln

    /// Sichert den geöffneten Schlüssel im anderen Format; die Passphrase bleibt dieselbe.
    func convert(to format: KeyFormat) {
        guard let key else { return }
        let panel: NSSavePanel = NSSavePanel()
        let base: String = key.url.pathExtension == "ppk" ? key.url.deletingPathExtension().lastPathComponent : key.url.lastPathComponent
        panel.nameFieldStringValue = format == .putty ? base + ".ppk" : base
        panel.message = format == .putty ? "PuTTY-Schlüssel (.ppk) für plink und PuTTY" : "OpenSSH-Schlüssel für ssh -i und ssh-add"
        panel.directoryURL = key.url.deletingLastPathComponent()
        panel.showsHiddenFiles = true
        run(panel) { [weak self] output in
            // Erst ohne Passphrase versuchen; ein geschützter Schlüssel meldet „falsche Passphrase“ – dann fragen
            self?.convert(key.url, to: format, output: output, passphrase: Data(), askOnFailure: true)
        }
    }

    private func convert(_ url: URL, to format: KeyFormat, output: URL, passphrase: Data, askOnFailure: Bool) {
        work {
            let command: PuttygenCommand = try .convert(url.path, to: format, output: output.path)
            let result: HelperProcess.Result = try await HelperProcess.run(self.puttygen, command.arguments, secrets: [passphrase])
            guard result.succeeded else {
                let problem: PuttygenProblem = PuttygenCommand.problem(fromErrorOutput: result.output)
                if problem == .wrongPassphrase || problem == .passphraseNeeded {
                    self.passphraseRequest = PassphraseRequest(action: .convert(url, format, output), wasWrong: !askOnFailure)
                    return
                }
                throw KeyFailure(problem: problem)
            }
            try await self.read(output, passphrase: passphrase.isEmpty ? nil : passphrase)
            self.message = format == .putty ? "Als PuTTY-Schlüssel gesichert." : "Als OpenSSH-Schlüssel gesichert."
        }
    }

    /// Antwort aus dem Passphrase-Sheet.
    func answer(_ request: PassphraseRequest, passphrase text: String) {
        passphraseRequest = nil
        if let problem = Self.passphraseProblem(text) {
            message = problem
            return
        }
        let secret: Data = Data(text.utf8)
        switch request.action {
        case .load(let url): load(url, passphrase: secret)
        case .convert(let url, let format, let output): convert(url, to: format, output: output, passphrase: secret, askOnFailure: false)
        }
    }

    // MARK: - Weitergeben

    func copyFingerprint() {
        guard let key else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(key.fingerprint, forType: .string)
        message = "Fingerabdruck kopiert."
    }

    func copyPublicKey() {
        guard let key else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(key.publicKey, forType: .string)
        message = "Öffentlicher Schlüssel kopiert."
    }

    /// Befehl für das Terminal auf dem Server: hängt den öffentlichen Schlüssel an `~/.ssh/authorized_keys` an.
    /// Kein automatisches Schreiben auf fremde Server (Plan M3).
    var installCommand: String? {
        key.map { Self.installCommand(for: $0.publicKey) }
    }

    /// `printf` statt `echo` (deutet weder Backslashes noch „-e“); das Zeilenende davor trennt von einer letzten Zeile ohne
    /// Zeilenende, eine Leerzeile stört `authorized_keys` nicht.
    static func installCommand(for publicKey: String) -> String {
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh && printf '\\n%s\\n' \(shellQuoted(publicKey)) >> ~/.ssh/authorized_keys"
            + " && chmod 600 ~/.ssh/authorized_keys"
    }

    /// puttygen liest die Passphrase als eine Zeile; mit Zeilenumbruch gälte nur der Anfang.
    static func passphraseProblem(_ passphrase: String) -> String? {
        passphrase.contains(where: \.isNewline) ? "Die Passphrase darf keinen Zeilenumbruch enthalten." : nil
    }

    func copyInstallCommand() {
        guard let installCommand else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(installCommand, forType: .string)
        message = "Befehl kopiert – auf dem Server im Terminal einfügen."
    }

    /// Der geöffnete Schlüssel ist eine OpenSSH-Datei (für ssh-add); `.ppk` versteht ssh-add nicht.
    var isOpenSSHFile: Bool {
        guard let key else { return false }
        return key.url.pathExtension != "ppk"
    }

    var agentCommand: String? {
        guard isOpenSSHFile, let key else { return nil }
        return "ssh-add --apple-use-keychain \(Self.shellQuoted(key.url.path))"
    }

    /// Einfache Anführungszeichen für die Shell (Kommentare fremder Schlüssel können „'“ enthalten).
    private static func shellQuoted(_ text: String) -> String {
        "'" + text.replacing("'", with: "'\\''") + "'"
    }

    // MARK: - Hilfen

    private static var existingSSHFolder: URL {
        FileManager.default.fileExists(atPath: sshFolder.path) ? sshFolder : FileManager.default.homeDirectoryForCurrentUser
    }

    private func run(_ panel: NSSavePanel, then action: @escaping (URL) -> Void) {
        guard let window else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            action(url)
        }
    }

    /// Eine Arbeit nach der anderen; Fehler erscheinen als Meldung im Fenster.
    private func work(_ body: @escaping () async throws -> Void) {
        guard !isWorking else { return }
        isWorking = true
        message = nil
        Task {
            defer { isWorking = false }
            do {
                try await body()
            } catch {
                message = error.message
            }
        }
    }
}

/// Fehler aus puttygen bzw. den Prüfregeln für die Meldung im Fenster.
private struct KeyFailure: Error {
    let problem: PuttygenProblem
}

private extension Error {
    var message: String {
        switch self {
        case let error as KeyFailure: error.problem.message
        case let error as InputError: error.message
        case let error as TerminalProcess.Failure: error.message
        default: localizedDescription
        }
    }
}
