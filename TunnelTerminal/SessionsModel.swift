import Foundation
import Observation
import TunnelTerminalCore

/// Zustand der Seitenleiste eines Hauptfensters: Auswahl, Suche, Editor, Importvorschau und die Befehle darauf.
/// Je Fenster eins; die Bibliothek teilen sich alle Fenster.
@Observable
final class SessionsModel {
    /// Fehlermeldung für die Oberfläche.
    struct Failure: Equatable {
        let message: String
    }

    /// Sitzung im Editor-Sheet. Die Kennung bleibt beim Umbenennen gleich, damit das Sheet offen bleibt.
    struct EditedSession: Identifiable {
        let id: UUID = UUID()
        var name: String
    }

    let library: SessionLibrary
    /// Profile für die Auswahl im Editor (M4).
    let profiles: ProfileStore
    var selection: Set<String> = []
    var search: String = ""
    var importPreview: ImportPreview?
    var editing: EditedSession?
    /// „Verbinden“ im Editor-Sheet: Sitzung, die nach dem Schließen verbunden wird (folgt einem Umbenennen).
    @ObservationIgnored var pendingConnection: String?
    var failure: Failure?
    var isShowingFailure: Bool = false

    /// Vom Fenster-Controller gesetzt: Undo-Verwaltung des Fensters und Öffnen einer Verbindung.
    @ObservationIgnored var undoManager: () -> UndoManager? = { nil }
    @ObservationIgnored var onConnect: (String) -> Void = { _ in }
    /// Blendet die Seitenleiste ein, bevor ein Sheet oder eine Meldung erscheint (sie hängen an der Seitenleiste).
    @ObservationIgnored var revealSidebar: () -> Void = {}
    /// Importquelle in der Dateiauswahl (Ablage > Importieren).
    enum ImportSource {
        case registry, folder
    }

    /// Öffnet die Dateiauswahl für den Import.
    @ObservationIgnored var onImport: (ImportSource) -> Void = { _ in }

    init(library: SessionLibrary, profiles: ProfileStore = AppIdentity.profiles) {
        self.profiles = profiles
        self.library = library
    }

    /// Ausgewählte Sitzungen, mit denen man verbinden kann (nicht die Standardeinstellungen).
    var connectableSelection: [String] {
        selection.sorted().filter { $0 != SessionName.defaultSettings && library.names.contains($0) }
    }

    /// Ausgewählte gespeicherte Sitzungen (auch die Standardeinstellungen, falls gespeichert).
    var savedSelection: [String] { selection.sorted().filter(library.names.contains) }

    /// Inhalt für den Editor: nur vorhandene Sitzungen; die Standardeinstellungen auch ungespeichert (dann die Vorlage).
    func editableFile(named name: String) -> SessionFile? {
        if library.names.contains(name) { return library.file(named: name) }
        return name == SessionName.defaultSettings ? library.template() : nil
    }

    /// Nach ⌘Z, Löschen usw.: Auswahl auf vorhandene Sitzungen beschränken.
    func dropMissingSelection() {
        let kept: Set<String> = selection.filter { $0 == SessionName.defaultSettings || library.names.contains($0) }
        if kept != selection { selection = kept }
        if let name = editing?.name, name != SessionName.defaultSettings, !library.names.contains(name) { editing = nil }
    }

    /// Öffnet den Editor (nach „Neue Sitzung“).
    func edit(_ name: String) {
        revealSidebar()
        editing = EditedSession(name: name)
    }

    /// Editor für genau eine ausgewählte Sitzung (Kontextmenü, Stift-Knopf, Verbindung > Sitzung bearbeiten …).
    func editSelection() {
        guard selection.count == 1, let name = selection.first else { return }
        edit(name)
    }

    /// Nach dem Schließen des Editor-Sheets (`onDismiss`).
    func connectAfterEditing() {
        guard let name = pendingConnection else { return }
        pendingConnection = nil
        connect([name])
    }

    func report(_ error: any Error) {
        revealSidebar()
        failure = Failure(message: (error as? InputError)?.message ?? error.localizedDescription)
        isShowingFailure = true
    }

    func connect(_ names: some Sequence<String>) {
        for name in names.sorted() where name != SessionName.defaultSettings && library.names.contains(name) {
            onConnect(name)
        }
    }

    func newSession() {
        do {
            let name: String = try library.create(undoManager: undoManager())
            selection = [name]
            edit(name)
        } catch {
            report(error)
        }
    }

    func duplicateSelection() {
        do {
            let copies: [String] = try library.duplicate(savedSelection, undoManager: undoManager())
            if !copies.isEmpty { selection = Set(copies) }
        } catch {
            report(error)
        }
    }

    func deleteSelection() {
        let targets: [String] = savedSelection
        guard !targets.isEmpty else { return }
        do {
            try library.delete(targets, undoManager: undoManager())
            selection = []
        } catch {
            report(error)
        }
    }

    /// Umbenennen aus dem Editor; die Auswahl folgt dem neuen Namen.
    func rename(_ oldName: String, to newName: String) throws {
        try library.rename(oldName, to: newName, undoManager: undoManager())
        selection = [newName]
        if editing?.name == oldName { editing?.name = newName }
        if pendingConnection == oldName { pendingConnection = newName }
    }

    func save(_ file: SessionFile, as name: String) throws {
        try library.save(file, as: name)
    }

    // MARK: - Import

    /// Liest eine `.reg`-Datei oder einen PuTTY-Ordner und zeigt die Vorschau.
    func prepareImport(from url: URL) {
        do {
            let values: URLResourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])
            let sessions: [ImportedSession]
            var unreadable: [String] = []
            if values.isDirectory == true {
                let reading: PuTTYFolder.Reading = try PuTTYFolder.sessions(in: url)
                sessions = reading.sessions
                unreadable = reading.unreadable
            } else {
                guard values.isRegularFile == true, (values.fileSize ?? .max) <= RegistryFile.maximumSize else {
                    throw InputError.notAnExport
                }
                // Höchstens ein Byte über der Grenze lesen: wächst die Datei inzwischen, lehnt der Leser sie ab
                let handle: FileHandle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                sessions = try RegistryFile.sessions(from: try handle.read(upToCount: RegistryFile.maximumSize + 1) ?? Data())
            }
            let candidates: [ImportCandidate] = SessionImport.candidates(
                for: sessions, existingNames: library.names, reservedPrefix: AppIdentity.quickSessionPrefix)
            revealSidebar()
            importPreview = ImportPreview(source: url.lastPathComponent, candidates: candidates, unreadable: unreadable)
        } catch {
            report(error)
        }
    }

    func finishImport() {
        guard let preview = importPreview else { return }
        importPreview = nil
        do {
            let names: [String] = try library.importSessions(preview.chosenCandidates, undoManager: undoManager())
            if !names.isEmpty { selection = Set(names) }
        } catch {
            report(error)
        }
    }
}

/// Inhalt der Importvorschau mit den angehakten Sitzungen.
@Observable
final class ImportPreview: Identifiable {
    let source: String
    let candidates: [ImportCandidate]
    let unreadable: [String]
    /// Häkchen je Kandidat (Index = `ImportCandidate.id`).
    var chosen: [Bool]

    init(source: String, candidates: [ImportCandidate], unreadable: [String]) {
        self.source = source
        self.candidates = candidates
        self.unreadable = unreadable
        chosen = candidates.map(\.isPreselected)
    }

    var chosenCandidates: [ImportCandidate] {
        candidates.filter { chosen[$0.id] && $0.problem == nil }
    }
}
