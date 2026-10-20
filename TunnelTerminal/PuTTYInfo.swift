import Foundation
import TunnelTerminalCore

/// Eingebaute PuTTY-Werkzeuge (Plan M7, S7): Version zum Anzeigen und die offizielle Seite für neue Versionen.
enum PuTTYInfo {
    /// Offizielle PuTTY-Seite: neue Versionen, Sicherheitshinweise, Ankündigungen.
    static let website: URL = URL(string: "https://www.chiark.greenend.org.uk/~sgtatham/putty/")!

    /// Wie Updates kommen (Hilfe › PuTTY-Version, Einstellungen › Erweitert; S7).
    static let updateNote: String = "plink, pscp und puttygen sind fest in \(AppIdentity.name) eingebaut. Neue Versionen "
        + "und Sicherheitshinweise veröffentlicht das PuTTY-Projekt auf seiner Website. Bringt PuTTY ein Sicherheitsupdate, "
        + "kommt es mit einer neuen Version von \(AppIdentity.name)."

    /// Fragt plink aus dem App-Paket nach seiner Version (`plink -V`, außerhalb des Hauptthreads); `nil`, wenn nicht lesbar.
    static func release() async -> String? {
        guard let result = try? await HelperProcess.run(AppIdentity.plinkPath, ["-V"]) else { return nil }
        return PuTTYVersion.release(fromVersionOutput: result.output)
    }
}
