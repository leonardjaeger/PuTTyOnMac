import Foundation
import Observation
import TunnelTerminalCore

/// Die gespeicherten Sitzungen im eigenen PuTTY-Ordner (docs/CONTEXT.md: gespeicherte Sitzung, Gruppe).
/// Jede Änderung lässt sich mit ⌘Z widerrufen, wenn ein `UndoManager` mitkommt.
@Observable
final class SessionLibrary {
    /// Abschnitt der Seitenleiste: Sitzungen ohne Gruppe (`title == nil`) oder einer Gruppe.
    struct Group: Equatable, Identifiable {
        let title: String?
        let names: [String]
        var id: String { title ?? "" }
    }

    let directory: PuTTYDirectory
    /// Gespeicherte Passwörter (M3); `nil` in Tests ohne Schlüsselbund. Löschen und Umbenennen nehmen sie mit.
    let passwords: PasswordStore?
    private let reservedPrefix: String

    /// Alle gespeicherten Sitzungen, sortiert, ohne Schnellverbindungen; „Default Settings“, falls vorhanden.
    private(set) var names: [String] = []
    /// Zählt jedes Neuladen (Anlegen, Löschen, Umbenennen, Import, ⌘Z): Der Editor baut sich dann neu auf und
    /// bearbeitet nie eine Sitzung, die es so nicht mehr gibt. Normales Speichern im Editor zählt nicht mit.
    private(set) var revision: Int = 0
    /// Server je Sitzung, für die Suche.
    private var hosts: [String: String] = [:]

    init(directory: PuTTYDirectory, reservedPrefix: String = AppIdentity.quickSessionPrefix, passwords: PasswordStore? = nil) {
        self.directory = directory
        self.reservedPrefix = reservedPrefix
        self.passwords = passwords
        reload()
    }

    /// `countsAsChange`: `true` nach eigenen Änderungen (Anlegen, Umbenennen, Import, ⌘Z), `false` beim Speichern im
    /// Editor, `nil` beim Nachladen fremder Änderungen – dann nur, wenn sich die Namen geändert haben. Sonst baute sich ein
    /// offener Editor bei jedem neuen Fenster neu auf und verlöre den Fokus.
    func reload(countsAsChange: Bool? = nil) {
        let folded: String = reservedPrefix.lowercased()
        let previous: [String] = names
        names = directory.sessionNames().filter { !$0.lowercased().hasPrefix(folded) }
        hosts = Dictionary(names.map { ($0, file(named: $0)?.hostName ?? "") }, uniquingKeysWith: { first, _ in first })
        if countsAsChange ?? (names != previous) { revision += 1 }
    }

    /// Server einer Sitzung (leer, wenn keiner eingetragen ist).
    func host(of name: String) -> String { hosts[name] ?? "" }

    func file(named name: String) -> SessionFile? {
        try? directory.read(sessionNamed: name)
    }

    /// Abschnitte für die Seitenleiste ohne „Default Settings“. Die Suche prüft Name und Server, ohne Groß/klein.
    func groups(matching search: String) -> [Group] {
        let query: String = search.trimmingCharacters(in: .whitespaces)
        let shown: [String] = names.filter { name in
            name != SessionName.defaultSettings && (query.isEmpty || name.localizedCaseInsensitiveContains(query)
                || (hosts[name] ?? "").localizedCaseInsensitiveContains(query))
        }
        var order: [String?] = []
        var members: [String?: [String]] = [:]
        for name in shown {
            let group: String? = SessionName.group(of: name)
            if members[group] == nil { order.append(group) }
            members[group, default: []].append(name)
        }
        // Wie im Finder: ohne Groß/klein, Umlaute an ihrem Platz, Zahlen nach Wert
        let sortedGroups: [String?] = order.sorted { ($0 ?? "").localizedStandardCompare($1 ?? "") == .orderedAscending }
        return sortedGroups.map { group in
            Group(title: group, names: (members[group] ?? []).sorted {
                SessionName.title(of: $0).localizedStandardCompare(SessionName.title(of: $1)) == .orderedAscending
            })
        }
    }

    /// Speichert die Einstellungen einer Sitzung (Editor). Ohne Undo: Textfelder haben ihr eigenes.
    func save(_ file: SessionFile, as name: String) throws {
        try directory.write(file, sessionName: name)
        // Erstes Speichern der Standardeinstellungen: in die Liste, ohne den Editor neu aufzubauen
        if !names.contains(name) { reload(countsAsChange: false) } else { hosts[name] = file.hostName }
    }

    // MARK: - Änderungen mit Undo

    /// Vorlage für neue Sitzungen und für noch nicht gespeicherte Standardeinstellungen:
    /// die Standardeinstellungen, ohne sie SSH auf Port 22 mit xterm-256color.
    func template() -> SessionFile {
        if let defaults = file(named: SessionName.defaultSettings) { return defaults }
        var file: SessionFile = SessionFile()
        try? file.setValue("1", forKey: "Present")
        file.setConnectionProtocol(.ssh)
        try? file.setPortNumber(22)
        try? file.setTerminalType("xterm-256color")   // plink übernimmt $TERM nicht (M0, B11)
        return file
    }

    @discardableResult
    func create(undoManager: UndoManager?) throws -> String {
        let template: SessionFile = template()
        let name: String = SessionName.available("Neue Sitzung", existing: names)
        try SessionName.check(name, reservedPrefix: reservedPrefix)
        try apply([(name, template)], actionName: "Neue Sitzung", undoManager: undoManager)
        return name
    }

    func rename(_ oldName: String, to newName: String, undoManager: UndoManager?) throws {
        guard oldName != SessionName.defaultSettings else { throw InputError.reservedName }
        guard oldName != newName else { return }
        try SessionName.check(newName, reservedPrefix: reservedPrefix)
        if SessionName.fileKey(oldName) != SessionName.fileKey(newName), directory.exists(sessionNamed: newName) {
            throw InputError.nameTaken
        }
        try directory.renameSession(from: oldName, to: newName)
        passwords?.rename(from: oldName, to: newName)
        reload(countsAsChange: true)
        undoManager?.registerUndo(withTarget: self) { library in
            try? library.rename(newName, to: oldName, undoManager: undoManager)
        }
        undoManager?.setActionName("Umbenennen")
    }

    /// Kopien unter freien Namen („A 2“). Gibt die neuen Namen zurück.
    func duplicate(_ sources: [String], undoManager: UndoManager?) throws -> [String] {
        var taken: [String] = names
        var changes: [(String, SessionFile?)] = []
        for source in sources where source != SessionName.defaultSettings {
            guard let file = file(named: source) else { continue }
            let name: String = SessionName.available(source, existing: taken)
            try SessionName.check(name, reservedPrefix: reservedPrefix)   // „Name 2“ kann zu lang werden
            taken.append(name)
            changes.append((name, file))
        }
        try apply(changes, actionName: "Duplizieren", undoManager: undoManager)
        return changes.map(\.0)
    }

    func delete(_ targets: [String], undoManager: UndoManager?) throws {
        try apply(targets.map { ($0, nil) }, actionName: "Löschen", undoManager: undoManager)
    }

    /// Speichert die Kandidaten ohne Problem. „Default Settings“ ersetzt die eigenen; ⌘Z stellt sie wieder her.
    func importSessions(_ candidates: [ImportCandidate], undoManager: UndoManager?) throws -> [String] {
        let accepted: [ImportCandidate] = candidates.filter { $0.problem == nil }
        try apply(accepted.map { ($0.name, $0.file) }, actionName: "Importieren", undoManager: undoManager)
        return accepted.map(\.name)
    }

    /// Schreibt (`SessionFile`) bzw. löscht (`nil`) Sitzungen und merkt sich den vorigen Stand für ⌘Z.
    private func apply(_ changes: [(String, SessionFile?)], actionName: String, undoManager: UndoManager?) throws {
        guard !changes.isEmpty else { return }
        var previous: [(String, SessionFile?)] = []
        defer {
            reload(countsAsChange: true)
            if !previous.isEmpty {
                let restore: [(String, SessionFile?)] = previous.reversed()
                undoManager?.registerUndo(withTarget: self) { library in
                    try? library.apply(restore, actionName: actionName, undoManager: undoManager)
                }
                undoManager?.setActionName(actionName)
            }
        }
        for (name, file) in changes {
            // Nur ändern, was sich wiederherstellen lässt: eine vorhandene, aber nicht lesbare Datei bleibt unberührt
            let before: SessionFile? = directory.exists(sessionNamed: name) ? try directory.read(sessionNamed: name) : nil
            if let file {
                try directory.write(file, sessionName: name)
            } else {
                directory.removeSession(named: name)
                // Das Passwort geht mit der Sitzung (Plan M3); ⌘Z bringt die Sitzung zurück, das Passwort nicht
                passwords?.delete(session: name)
            }
            previous.append((name, before))
        }
    }

    // MARK: - Export

    /// Registrierungsdatei für Windows-PuTTY (UTF-16LE, wie regedit). Nicht lesbare Sitzungen fehlen.
    func registryExport(of selected: [String]) -> Data {
        RegistryFile.data(for: selected.compactMap { name in file(named: name).map { (name: name, file: $0) } })
    }

    /// Schreibt den Export nur für den Benutzer lesbar (0600) wie die Sitzungsdateien; vorhandene Datei wird ersetzt
    /// (das hat der Sichern-Dialog bestätigt).
    func writeRegistryExport(of selected: [String], to url: URL) throws {
        let data: Data = registryExport(of: selected)
        let temporary: URL = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).reg")
        guard FileManager.default.createFile(atPath: temporary.path, contents: data,
                                             attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                // neue Metadaten, sonst übernähme die Datei die (meist offeneren) Rechte der alten
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary, options: .usingNewMetadataOnly)
            } else {
                try FileManager.default.moveItem(at: temporary, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    /// PuTTY-Ordner für PuTTY unter macOS/Linux (`<Ziel>/sessions/<Name>`, Ordner 0700, Dateien 0600).
    /// Ein vorhandener Ordner muss leer oder schon ein PuTTY-Ordner sein (seine Rechte werden auf 0700 gesetzt).
    func exportFolder(of selected: [String], to url: URL) throws {
        let manager: FileManager = FileManager.default
        if let contents = try? manager.contentsOfDirectory(atPath: url.path), !contents.isEmpty,
           !contents.contains("sessions") {
            throw InputError.notAPuTTYFolder
        }
        let target: PuTTYDirectory = try PuTTYDirectory(url: url)
        for name in selected {
            guard let file = file(named: name) else { continue }
            try target.write(file, sessionName: name)
        }
    }
}
