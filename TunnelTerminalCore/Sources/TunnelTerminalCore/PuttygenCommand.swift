/// Schlüsseltyp beim Erzeugen (Plan M3: Ed25519 Standard; ECDSA und RSA für ältere Server).
public enum KeyKind: String, CaseIterable, Identifiable, Sendable {
    case ed25519, ecdsa, rsa

    public static let standard: KeyKind = .ed25519
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ed25519: "Ed25519 (empfohlen)"
        case .ecdsa: "ECDSA P-256"
        case .rsa: "RSA 4096 Bit (für ältere Server)"
        }
    }

    fileprivate var arguments: [String] {
        switch self {
        case .ed25519: ["-t", "ed25519"]
        case .ecdsa: ["-t", "ecdsa", "-b", "256"]
        case .rsa: ["-t", "rsa", "-b", "4096"]
        }
    }
}

/// Format beim Umwandeln eines privaten Schlüssels.
public enum KeyFormat: Sendable {
    /// PuTTY (`.ppk`)
    case putty
    /// OpenSSH (für `ssh -i`)
    case openSSH
}

/// Was beim Lesen oder Umwandeln schiefging.
public enum PuttygenProblem: Equatable, Sendable {
    case passphraseNeeded
    case wrongPassphrase
    case other(String)

    public var message: String {
        switch self {
        case .passphraseNeeded: "Der Schlüssel ist mit einer Passphrase geschützt."
        case .wrongPassphrase: "Die Passphrase ist falsch."
        case .other(let text): text
        }
    }
}

/// Aufruf von puttygen (Schlüssel-Fenster, M3). Passphrasen nie als Argument: puttygen liest sie aus
/// `/dev/fd/3` (die App gibt dort eine Pipe weiter, S1); ohne Steuerterminal fragt puttygen nicht nach, sondern bricht
/// ab (docs/M3-Recherche.md 2). Dateien nur als absolute Pfade, sonst könnte ein Name mit „-“ als Option gelten.
public struct PuttygenCommand: Equatable, Sendable {
    public let arguments: [String]

    private static let passphrase: String = "/dev/fd/3"

    public static func generate(_ kind: KeyKind, comment: String, output: String) throws(InputError) -> PuttygenCommand {
        try checkPath(output)
        guard !comment.hasPrefix("-") else { throw .leadingDash(.comment) }
        for scalar in comment.unicodeScalars where InputRules.isControl(scalar) { throw .controlCharacter(.comment) }
        guard comment.utf8.count <= 256 else { throw .tooLong(.comment) }
        return PuttygenCommand(arguments: kind.arguments + ["-C", comment, "-q", "-o", output, "--new-passphrase", passphrase])
    }

    /// Öffentlicher Schlüssel als OpenSSH-Zeile (für `authorized_keys`).
    public static func publicKey(of file: String, withPassphrase: Bool) throws(InputError) -> PuttygenCommand {
        try reading(file, ["-L"], withPassphrase: withPassphrase)
    }

    public static func fingerprint(of file: String, withPassphrase: Bool) throws(InputError) -> PuttygenCommand {
        try reading(file, ["-l", "-E", "sha256"], withPassphrase: withPassphrase)
    }

    /// Schreibt den privaten Schlüssel im anderen Format; die Passphrase bleibt dieselbe (puttygen übernimmt die alte).
    public static func convert(_ file: String, to format: KeyFormat, output: String) throws(InputError) -> PuttygenCommand {
        try checkPath(file)
        try checkPath(output)
        let type: String = format == .putty ? "private" : "private-openssh"
        return PuttygenCommand(arguments: [file, "-O", type, "-o", output, "--old-passphrase", passphrase])
    }

    private static func reading(_ file: String, _ options: [String], withPassphrase: Bool) throws(InputError) -> PuttygenCommand {
        try checkPath(file)
        return PuttygenCommand(arguments: [file] + options + (withPassphrase ? ["--old-passphrase", passphrase] : []))
    }

    private static func checkPath(_ path: String) throws(InputError) {
        try InputRules.checkAbsolutePath(path)
    }

    // MARK: - Ausgaben

    /// „ssh-ed25519 255 SHA256:… Kommentar“ → „SHA256:…“.
    public static func fingerprint(fromOutput output: String) -> String? {
        output.split(whereSeparator: \.isWhitespace).first { $0.hasPrefix("SHA256:") }.map(String.init)
    }

    /// Erste Zeile von `-L`, nur wenn sie wie ein öffentlicher Schlüssel aussieht und keine Steuerzeichen enthält
    /// (sie wird angezeigt und kopiert).
    public static func publicKey(fromOutput output: String) -> String? {
        guard let line = output.split(separator: "\n").first.map(String.init),
              line.hasPrefix("ssh-") || line.hasPrefix("ecdsa-"),
              !line.unicodeScalars.contains(where: InputRules.isControl) else { return nil }
        return line
    }

    public static func problem(fromErrorOutput output: String) -> PuttygenProblem {
        if output.contains("wrong passphrase") { return .wrongPassphrase }
        if output.contains("Enter passphrase") { return .passphraseNeeded }
        let line: String = output.split(separator: "\n").first.map(String.init) ?? "Unbekannter Fehler"
        // „puttygen: error loading `pfad': grund“ – der Pfad steht schon im Fenster
        if let reason = line.range(of: "': ") { return .other("Fehler beim Laden: " + line[reason.upperBound...]) }
        return .other(line.replacingOccurrences(of: "puttygen: ", with: ""))
    }
}
