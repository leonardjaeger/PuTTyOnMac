import Foundation
import TunnelTerminalCore

/// Name und feste Kennungen an einer Stelle (umbenannt in U1; Bundle-ID und Schlüsselbund hängen daran).
enum AppIdentity {
    nonisolated static let name: String = "TunnelTerminal"
    nonisolated static let logSubsystem: String = "de.leonardjaeger.tunnelterminal"
    /// Präfix der vorübergehenden Sitzungen für Schnellverbindungen im eigenen PuTTY-Ordner.
    static let quickSessionPrefix: String = "\(name)-Schnell-"

    /// Passwörter gespeicherter Sitzungen (M3, S1); Dienstname im Schlüsselbund hängt an der Bundle-ID.
    static let passwords: PasswordStore = PasswordStore(service: "\(logSubsystem).passwort")

    /// Profile (M4), eine Liste für alle Fenster.
    static let profiles: ProfileStore = ProfileStore()

    /// plink aus dem App-Paket (gebaut von Scripts/build-putty.sh, nie ein fremder Build).
    static var plinkPath: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/plink").path
    }

    /// Eigener PuTTY-Ordner, damit nichts mit einer Homebrew-PuTTY in ~/.putty kollidiert (Plan Abschnitt 3).
    static func puttyDirectory() throws -> PuTTYDirectory {
        let support: URL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true)
        return try PuTTYDirectory(url: support.appendingPathComponent("\(name)/putty", isDirectory: true))
    }
}
