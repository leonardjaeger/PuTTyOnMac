/// Aufruf von plink für eine gespeicherte Sitzung (Plan S3).
///
/// plink kennt kein `--` (docs/M1-Recherche.md 3.1). Deshalb gehen Server, Benutzer und alle übrigen Werte über
/// die Sitzungsdatei; auf der Kommandozeile steht nur `-load <Sitzungsname>`. Die Umgebung ist eine feste
/// Liste: keine fremden PuTTY-Ablagen (`PUTTYSESSIONS`, `PLINK_PROTOCOL` …) und keine `DYLD_*`-Variablen.
public struct PlinkCommand: Equatable, Sendable {
    public let arguments: [String]
    public let environment: [String]

    /// Aus der Umgebung der App übernommen; alles andere setzt die App selbst.
    private static let passedThrough: [String] = ["HOME", "LANG", "LOGNAME", "SSH_AUTH_SOCK", "USER"]

    public init(sessionName: String, puttyDirectory: String, parentEnvironment: [String: String]) throws(InputError) {
        try InputRules.checkSessionName(sessionName)
        arguments = ["-load", sessionName]

        var values: [String: String] = [
            "COLORTERM": "truecolor",
            "LANG": "en_US.UTF-8",
            "PUTTYDIR": puttyDirectory,
            "TERM": "xterm-256color"
        ]
        for name in Self.passedThrough {
            if let value = parentEnvironment[name], !value.isEmpty { values[name] = value }
        }
        environment = values.keys.sorted().map { "\($0)=\(values[$0]!)" }
    }
}
