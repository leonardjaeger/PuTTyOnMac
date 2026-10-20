import AppKit
import UniformTypeIdentifiers

/// Import und Export gespeicherter Sitzungen (M2): Ablage › Importieren / Exportieren. Aus dem Fenster-Controller
/// ausgelagert (Code-Review M4/M5); die Dialoge hängen als Sheet am Fenster des Tabs.
extension ConnectionWindowController {
    private static let registryType: UTType = UTType(filenameExtension: "reg") ?? .data

    /// Registrierungsdatei (`.reg`) aus Windows-PuTTY.
    @objc func importRegistry(_ sender: Any?) {
        let panel: NSOpenPanel = NSOpenPanel()
        panel.message = "Registrierungsdatei (.reg) aus Windows-PuTTY wählen (regedit: Export von HKEY_CURRENT_USER\\Software\\SimonTatham)"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [Self.registryType]
        runImportPanel(panel, startingIn: FileManager.default.homeDirectoryForCurrentUser)
    }

    /// PuTTY-Ordner von PuTTY für macOS/Linux (`~/.config/putty`, `~/.putty`). Eine Auswahl „Datei oder Ordner“ in einem
    /// Dialog geht nicht: NSOpenPanel öffnet einen markierten Ordner dann, statt ihn zu wählen.
    @objc func importFolder(_ sender: Any?) {
        let panel: NSOpenPanel = NSOpenPanel()
        panel.message = "PuTTY-Ordner wählen (enthält den Unterordner „sessions“, z. B. ~/.config/putty)"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        let home: URL = FileManager.default.homeDirectoryForCurrentUser
        let known: URL? = [".config/putty", ".putty"].map { home.appendingPathComponent($0, isDirectory: true) }
            .first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("sessions").path) }
        runImportPanel(panel, startingIn: known ?? home)
    }

    private func runImportPanel(_ panel: NSOpenPanel, startingIn directory: URL) {
        guard let window else { return }
        panel.prompt = "Importieren"
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true   // ~/.config und ~/.putty sind versteckt
        panel.directoryURL = directory
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.sessions.prepareImport(from: url)
        }
    }

    @objc func exportRegistry(_ sender: Any?) {
        guard let window else { return }
        let names: [String] = exportNames
        let panel: NSSavePanel = NSSavePanel()
        panel.message = "Für Windows-PuTTY: Datei doppelklicken oder mit regedit importieren"
        panel.nameFieldStringValue = "PuTTY-Sitzungen.reg"
        panel.allowedContentTypes = [Self.registryType]
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                try self.sessions.library.writeRegistryExport(of: names, to: url)
            } catch {
                self.sessions.report(error)
            }
        }
    }

    @objc func exportFolder(_ sender: Any?) {
        guard let window else { return }
        let names: [String] = exportNames
        let panel: NSSavePanel = NSSavePanel()
        panel.message = "Für PuTTY unter macOS oder Linux: Ordner als ~/.config/putty verwenden oder dorthin kopieren"
        panel.nameFieldStringValue = "putty"
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                try self.sessions.library.exportFolder(of: names, to: url)
            } catch {
                self.sessions.report(error)
            }
        }
    }

    /// Ausgewählte Sitzungen, ohne Auswahl alle.
    private var exportNames: [String] {
        sessions.savedSelection.isEmpty ? sessions.library.names : sessions.savedSelection
    }
}
