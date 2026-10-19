/// Eine Sitzung aus einer Importquelle (Registrierungs-Export oder PuTTY-Ordner), noch nicht gespeichert.
/// Der Name ist noch nicht geprüft; das übernimmt der Import (`SessionName.check`).
public struct ImportedSession: Equatable, Sendable {
    public var name: String
    public var file: SessionFile
    /// Was beim Lesen übersprungen wurde. Nennt nur Schlüssel, nie Werte.
    public var notes: [String]

    public init(name: String, file: SessionFile, notes: [String] = []) {
        self.name = name
        self.file = file
        self.notes = notes
    }
}
