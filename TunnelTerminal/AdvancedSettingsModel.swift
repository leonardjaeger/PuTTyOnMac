import AppKit
import Observation

/// Einstellungen › Erweitert (Plan M7): Standard-App für `ssh://`/`telnet://`, eingebaute PuTTY-Version, Ordner der App.
@Observable
final class AdvancedSettingsModel {
    /// Schemata, die die App laut Info.plist (`CFBundleURLTypes`) öffnen kann – eine Quelle, keine zweite Liste.
    static let schemes: [String] = (Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? [])
        .flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }

    /// Name der App, die das Schema gerade öffnet (`nil`: keine).
    private(set) var handlers: [String: String] = [:]
    private(set) var isDefaultHandler: Bool = false
    private(set) var puttyRelease: String?
    private(set) var failure: String?

    func load() async {
        refreshHandlers()
        puttyRelease = await PuTTYInfo.release()
    }

    func refreshHandlers() {
        var names: [String: String] = [:]
        var allOurs: Bool = true
        for scheme in Self.schemes {
            guard let probe = URL(string: "\(scheme)://server.example"),
                  let app = NSWorkspace.shared.urlForApplication(toOpen: probe) else {
                allOurs = false
                continue
            }
            names[scheme] = FileManager.default.displayName(atPath: app.path)
            if Bundle(url: app)?.bundleIdentifier != Bundle.main.bundleIdentifier { allOurs = false }
        }
        handlers = names
        isDefaultHandler = allOurs
    }

    /// macOS fragt dabei selbst nach, ob die Standard-App wechseln soll.
    func makeDefaultHandler() async {
        failure = nil
        for scheme in Self.schemes {
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme)
            } catch {
                failure = "\(scheme):// nicht geändert: \(error.localizedDescription)"
            }
        }
        refreshHandlers()
        if let failure {   // die rote Zeile allein liest VoiceOver nicht vor
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                                 userInfo: [.announcement: failure, .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }
    }

    func revealPuTTYFolder() {
        guard let directory = try? AppIdentity.puttyDirectory() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([directory.url])
    }

    var hasSessionLogs: Bool { FileManager.default.fileExists(atPath: SessionLogWriter.folder.path) }

    func revealSessionLogs() {
        NSWorkspace.shared.activateFileViewerSelecting([SessionLogWriter.folder])
    }
}
