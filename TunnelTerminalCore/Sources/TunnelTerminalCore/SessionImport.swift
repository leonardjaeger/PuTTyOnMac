/// Eine Zeile der Importvorschau.
public struct ImportCandidate: Identifiable, Equatable, Sendable {
    public let id: Int
    /// Name in der Quelle.
    public let originalName: String
    /// Name, unter dem gespeichert wird (bei Konflikt mit angehängter Nummer).
    public let name: String
    public let file: SessionFile
    public let notes: [String]
    public let warnings: [SessionWarning]
    /// Grund, warum die Sitzung nicht importiert werden kann.
    public let problem: InputError?

    public var replacesDefaultSettings: Bool { problem == nil && name == SessionName.defaultSettings }

    /// Vorausgewählt ist nur, was nichts ersetzt, nichts auf diesem Mac ausführt und keine Datei schreibt (Plan S4).
    public var isPreselected: Bool {
        problem == nil && !replacesDefaultSettings && !warnings.contains { $0.blocksPreselection }
    }
}

/// Bereitet gelesene Sitzungen für die Importvorschau auf.
public enum SessionImport {
    public static func candidates(for sessions: [ImportedSession], existingNames: [String],
                                  reservedPrefix: String) -> [ImportCandidate] {
        var taken: Set<String> = Set(existingNames.map(SessionName.fileKey))
        return sessions.enumerated().map { index, session in
            var name: String = session.name
            var problem: InputError?
            if session.file.contents.count > PuTTYDirectory.maximumSessionSize {
                problem = .invalidFile   // die App könnte die Datei später nicht lesen und vor dem Verbinden prüfen
            } else if name == SessionName.defaultSettings {
                // ersetzt die eigenen Standardeinstellungen, daher ohne Nummer
            } else {
                do throws(InputError) {
                    try SessionName.check(name, reservedPrefix: reservedPrefix)
                    name = SessionName.available(name, taken: taken)
                    try SessionName.check(name, reservedPrefix: reservedPrefix)
                    taken.insert(SessionName.fileKey(name))
                } catch {
                    problem = error
                }
            }
            var file: SessionFile = session.file
            var notes: [String] = session.notes
            if file.value(forKey: "ProxyPassword") != nil {
                file.removeValue(forKey: "ProxyPassword")
                notes.append("„ProxyPassword“ nicht übernommen (Passwörter speichert die App nur im Schlüsselbund).")
            }
            if problem == nil { problem = addressProblem(in: file) }
            return ImportCandidate(id: index, originalName: session.name, name: name, file: file,
                                   notes: notes, warnings: file.warnings, problem: problem)
        }
    }

    /// Server und Benutzer wie im Editor (S3): leer erlaubt, sonst die Regeln der Schnellverbindung.
    private static func addressProblem(in file: SessionFile) -> InputError? {
        var probe: SessionFile = SessionFile()
        do throws(InputError) {
            try probe.setHostName(file.hostName)
            try probe.setUserName(file.userName)
            return nil
        } catch {
            return error
        }
    }
}
