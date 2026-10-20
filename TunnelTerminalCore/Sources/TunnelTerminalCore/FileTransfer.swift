import Foundation

/// Ordner oder Datei auf dem Server, wie man sie eintippt (M6). pscp spricht SFTP, und sftp-server erweitert „~“
/// nicht (docs/M6-Machbarkeit.md 1): Pfade ohne „/“ am Anfang gelten ab dem persönlichen Ordner, ein „~/“ vorn
/// fällt dafür weg. Leerraum am Rand (eingefügte Zeile) zählt nicht, Steuerzeichen werden abgelehnt.
public struct RemotePath: Equatable, Sendable {
    /// Leer = persönlicher Ordner.
    public let path: String

    public init(_ text: String) throws(InputError) {
        var trimmed: String = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "~" {
            trimmed = ""
        } else if trimmed.hasPrefix("~/") {
            trimmed.removeFirst(2)
        }
        for scalar in trimmed.unicodeScalars where InputRules.isControl(scalar) { throw .controlCharacter(.remotePath) }
        guard trimmed.utf8.count <= 4_096 else { throw .tooLong(.remotePath) }
        path = trimmed
    }

    /// Letzter Teil des Pfads als Name auf dem Mac; `nil`, wenn der Pfad keine Datei nennt („/“ am Ende, „.“, „..“).
    public var localFileName: String? {
        let name: Substring = path.split(separator: "/", omittingEmptySubsequences: false).last ?? ""
        guard !name.isEmpty, name != ".", name != "..", name.utf8.count <= 255 else { return nil }
        return String(name)
    }
}

/// Aufruf von pscp für die Dateiübertragung (M6, docs/M6-Machbarkeit.md). Wie bei plink (S3) kommen alle Einstellungen
/// aus der Sitzungsdatei (`-load`); nur der Server muss zusätzlich ins Ziel „server:pfad“, weil pscp ihn von dort nimmt
/// und den der Sitzung damit ersetzt. Immer `-sftp` (bei SCP ginge der Zielpfad durch die Shell des Servers) und
/// `-batch` (ohne Terminal keine Abfrage; einen unbekannten Hostschlüssel lehnt pscp dann ab, S5). Kein „--“: pscp 0.85
/// überspringt das Argument danach (gemessen) – Dateien auf dem Mac sind deshalb absolut und beginnen nie mit „-“.
public struct PscpCommand: Equatable, Sendable {
    public let arguments: [String]
    public let environment: [String]

    /// Eine Datei in einen Ordner auf dem Server (pscp überschreibt dort ohne Frage – die App fragt vorher, `list`).
    public static func upload(_ file: String, to folder: RemotePath, host: String, sessionName: String,
                              puttyDirectory: String, parentEnvironment: [String: String],
                              passwordFromPipe: Bool) throws(InputError) -> PscpCommand {
        try InputRules.checkAbsolutePath(file)
        // pscp nimmt als Namen auf dem Server, was nach dem letzten „/“ und danach nach dem letzten „\“ steht
        guard !(file.split(separator: "/").last ?? "").contains("\\") else { throw .backslashInName }
        return try PscpCommand(sessionName: sessionName, puttyDirectory: puttyDirectory, parentEnvironment: parentEnvironment,
                               passwordFromPipe: passwordFromPipe, operands: [file, try remote(host, folder.path)])
    }

    /// Eine Datei vom Server in eine Datei auf dem Mac, deren Namen die App wählt (nie einen Namen vom Server).
    public static func download(_ file: RemotePath, to localFile: String, host: String, sessionName: String,
                                puttyDirectory: String, parentEnvironment: [String: String],
                                passwordFromPipe: Bool) throws(InputError) -> PscpCommand {
        guard file.localFileName != nil else { throw .notAFile }
        try InputRules.checkAbsolutePath(localFile)
        return try PscpCommand(sessionName: sessionName, puttyDirectory: puttyDirectory, parentEnvironment: parentEnvironment,
                               passwordFromPipe: passwordFromPipe, operands: [try remote(host, literal(file.path)), localFile])
    }

    /// Inhalt eines Ordners (`ls -l`-Zeilen vom Server); scheitert, wenn es den Ordner nicht gibt.
    public static func list(_ folder: RemotePath, host: String, sessionName: String, puttyDirectory: String,
                            parentEnvironment: [String: String], passwordFromPipe: Bool) throws(InputError) -> PscpCommand {
        try PscpCommand(sessionName: sessionName, puttyDirectory: puttyDirectory, parentEnvironment: parentEnvironment,
                        passwordFromPipe: passwordFromPipe, operands: ["-q", "-ls", try remote(host, folder.path)])
    }

    private init(sessionName: String, puttyDirectory: String, parentEnvironment: [String: String], passwordFromPipe: Bool,
                 operands: [String]) throws(InputError) {
        try InputRules.checkSessionName(sessionName)
        arguments = ["-load", sessionName, "-sftp", "-batch"] + (passwordFromPipe ? ["-pwfile", "/dev/fd/3"] : []) + operands
        environment = PlinkCommand.environment(puttyDirectory: puttyDirectory, parentEnvironment: parentEnvironment)
    }

    /// „server:pfad“; IPv6 in eckigen Klammern (pscp trennt am ersten „:“ außerhalb davon).
    private static func remote(_ host: String, _ path: String) throws(InputError) -> String {
        try InputRules.checkHost(host)
        guard host.count > 1 else { throw .singleCharacterHost }   // „x:pfad“ ist für pscp ein Pfad (colon() in pscp.c)
        return (host.contains(":") ? "[\(host)]" : host) + ":" + path
    }

    /// Joker maskiert wie `wc_unescape` (utils/wildcard.c) es zurückliest: vor `* ? [ ]` und `\` ein `\`.
    private static func literal(_ path: String) -> String {
        var result: String = ""
        for character in path {
            if "*?[]\\".contains(character) { result.append("\\") }
            result.append(character)
        }
        return result
    }
}

/// Warum eine Übertragung scheiterte (aus der Ausgabe von pscp).
public enum TransferFailure: Equatable, Sendable {
    /// pscp hätte nach einem Passwort (oder einer anderen Eingabe) fragen müssen.
    case passwordNeeded
    case passwordRejected
    /// Hostschlüssel unbekannt oder geändert: Ohne Terminal fragt pscp nicht, sondern bricht ab (S5).
    case hostKeyUnknown
    /// Letzte Meldung von pscp, Steuerzeichen sichtbar, gekürzt.
    case other(String)

    public var message: String {
        switch self {
        case .passwordNeeded: "Der Server verlangt ein Passwort."
        case .passwordRejected: "Das Passwort wurde nicht angenommen."
        case .hostKeyUnknown:
            "Der Hostschlüssel des Servers ist nicht bestätigt (unbekannt oder geändert). Zuerst im Terminal verbinden "
                + "und plinks Abfrage beantworten."
        case .other(let text): text
        }
    }
}

/// Ausgabe von pscp lesen (M6): Fortschritt, Ordnerinhalt, Fehler. Sie kommt von pscp und vom Server – wird nur
/// verglichen oder sichtbar gemacht angezeigt, nie ausgeführt.
public enum PscpOutput {
    /// Prozent der letzten vollständigen Fortschrittszeile („name | 123 kB | 4.0 kB/s | ETA: 00:00:01 | 42%“, `print_stats`
    /// in pscp.c); `nil` ohne solche Zeile.
    public static func percent(in text: String) -> Int? {
        for segment in segments(text).reversed() where segment.contains(" | ETA: ") {
            let trimmed: String = segment.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasSuffix("%"), let bar = trimmed.lastIndex(of: "|") else { continue }
            let digits: String = trimmed[trimmed.index(after: bar)...].dropLast().trimmingCharacters(in: .whitespaces)
            if let value = Int(digits), (0...100).contains(value) { return value }
        }
        return nil
    }

    /// Welche `names` stehen im Ordnerinhalt von `pscp -ls` (`ls -l`-Zeilen, die mit dem Namen enden)? Im Zweifel ja –
    /// etwa „leer zeichen.txt“ neben „mit leer zeichen.txt“: Dann fragt die App einmal zu viel, überschreibt aber nie still.
    /// Ohne Groß-/Kleinschreibung: Auf einem Mac als Server ersetzt „README.txt“ ein vorhandenes „Readme.txt“.
    /// Nicht auf dem Hauptthread: Große Ordner liefern Megabytes (RL 3.7).
    @concurrent
    public static func existing(_ names: [String], in text: String) async -> [String] {
        let lines: [Substring] = segments(text).filter { !$0.hasPrefix("Listing directory ") }
        let options: String.CompareOptions = [.caseInsensitive, .anchored, .backwards]   // nur das Zeilenende
        return names.filter { name in
            let ending: String = " " + name
            return lines.contains { $0.range(of: ending, options: options) != nil }
        }
    }

    public static func failure(in text: String) -> TransferFailure {
        if text.contains("Configured password was not accepted") { return .passwordRejected }
        if text.contains("Cannot answer interactive prompts in batch mode") { return .passwordNeeded }
        if text.contains("Cannot confirm a host key in batch mode") || text.contains("Cannot confirm a weak cached host key") {
            return .hostKeyUnknown
        }
        let isMessage: (Substring) -> Bool = { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.contains(" | ETA: ") }
        var message: String = (segments(text).last(where: isMessage) ?? "").trimmingCharacters(in: .whitespaces)
        for prefix in ["FATAL ERROR: ", "pscp: "] where message.hasPrefix(prefix) { message.removeFirst(prefix.count) }
        guard !message.isEmpty else { return .other("pscp ist ohne Meldung beendet.") }
        let visible: String = SessionWarning.visible(message)
        return .other(visible.count > 300 ? String(visible.prefix(300)) + "…" : visible)
    }

    /// Zeilen bzw. Fortschrittsstücke, getrennt an \r und \n (Swift zählt \r\n als ein Zeichen).
    private static func segments(_ text: String) -> [Substring] {
        text.split { $0 == "\r" || $0 == "\n" || $0 == "\r\n" }
    }
}
