import Foundation
import Testing

/// Grundsatz-Tests (fitness functions): Regeln aus Plan Abschnitt 3 und 6, die sonst nur als Text gelten.
/// Schlägt einer an, sagt die Meldung, welche Datei die Regel bricht und wo die Regel steht.
@Suite("Grundsätze")
struct ArchitectureTests {
    /// Wurzel des Repos aus dem Pfad dieser Datei (SSHAppCore/Tests/SSHAppCoreTests/…).
    private static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Ausgelieferter Code: App und Kern (ohne Tests) sowie die Bauskripte.
    private static let shippedFolders: [String] = ["SSHApp", "SSHAppCore/Sources", "Scripts"]

    private static func files(in folders: [String], extensions: Set<String>) -> [URL] {
        var result: [URL] = []
        for folder in folders {
            let base: URL = root.appendingPathComponent(folder)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where extensions.contains(url.pathExtension) {
                result.append(url)
            }
        }
        return result.sorted { $0.path < $1.path }
    }

    private static func lines(_ url: URL) -> [String] {
        let text: String = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return text.components(separatedBy: "\n")
    }

    private static func relative(_ url: URL) -> String {
        String(url.path.dropFirst(root.path.count + 1))
    }

    @Test("Die Suche findet Quelltext (sonst prüfen die übrigen Tests nichts)")
    func scannerFindsSources() {
        #expect(Self.files(in: ["SSHAppCore/Sources"], extensions: ["swift"]).count >= 4)
        #expect(Self.files(in: ["SSHApp"], extensions: ["swift"]).count >= 4)
        #expect(Self.files(in: ["Scripts"], extensions: ["sh"]).count >= 1)
    }

    @Test("Der Kern importiert kein AppKit, SwiftUI, Cocoa oder SwiftTerm (Plan 3)")
    func coreHasNoUIImports() {
        let forbidden: Set<String> = ["import AppKit", "import SwiftUI", "import Cocoa", "import SwiftTerm"]
        var offenders: [String] = []
        for file in Self.files(in: ["SSHAppCore/Sources"], extensions: ["swift"]) {
            for line in Self.lines(file) where forbidden.contains(line.trimmingCharacters(in: .whitespaces)) {
                offenders.append("\(Self.relative(file)): \(line)")
            }
        }
        #expect(offenders.isEmpty, "Kern muss ohne Oberfläche auskommen (Plan Abschnitt 3): \(offenders)")
    }

    @Test("Nirgends die Option -pw: Passwörter nie auf der Kommandozeile (S1)")
    func noPasswordOption() {
        // Muster zusammengesetzt, damit diese Datei sich nicht selbst findet
        let option: String = "-" + "pw"
        var offenders: [String] = []
        for file in Self.files(in: Self.shippedFolders, extensions: ["swift", "sh"]) {
            for (number, line) in Self.lines(file).enumerated() {
                guard let range = line.range(of: option) else { continue }
                let next: Character? = line[range.upperBound...].first
                // -pwfile ist erlaubt (Pipe, S1); -pw allein oder -pw <Wert> nicht
                if next == nil || !(next!.isLetter) {
                    offenders.append("\(Self.relative(file)):\(number + 1)")
                }
            }
        }
        #expect(offenders.isEmpty, "Passwort nur über Schlüsselbund und Pipe (S1): \(offenders)")
    }

    @Test("Keine persönlichen Pfade und kein #file im ausgelieferten Code (S14)")
    func noPersonalPaths() {
        let patterns: [String] = ["/" + "Users/", "#" + "file)", "#" + "filePath", "#" + "file,", "#" + "file "]
        var offenders: [String] = []
        for file in Self.files(in: Self.shippedFolders, extensions: ["swift", "sh", "plist", "entitlements"]) {
            for (number, line) in Self.lines(file).enumerated() where patterns.contains(where: { line.contains($0) }) {
                offenders.append("\(Self.relative(file)):\(number + 1)")
            }
        }
        #expect(offenders.isEmpty, "Keine Pfade mit Benutzernamen, #fileID statt #file (S14): \(offenders)")
    }

    @Test("Keine echten IPv4-Adressen im ausgelieferten Code (S14, nur 192.0.2.x, 127.0.0.1, 0.0.0.0)")
    func noRealAddresses() throws {
        let regex: NSRegularExpression = try NSRegularExpression(pattern: #"(?<![\d.])(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?![\d.])"#)
        var offenders: [String] = []
        for file in Self.files(in: Self.shippedFolders, extensions: ["swift", "sh", "plist"]) {
            for (number, line) in Self.lines(file).enumerated() {
                let range: NSRange = NSRange(line.startIndex..., in: line)
                for match in regex.matches(in: line, range: range) {
                    let address: String = (line as NSString).substring(with: match.range)
                    if address.hasPrefix("192.0.2.") || address == "127.0.0.1" || address == "0.0.0.0" { continue }
                    offenders.append("\(Self.relative(file)):\(number + 1) \(address)")
                }
            }
        }
        #expect(offenders.isEmpty, "Beispiele nur mit Dokumentations-Adressen (S14): \(offenders)")
    }

    @Test("Protokoll: jeder eingesetzte Wert hat eine ausdrückliche privacy-Angabe (S9)")
    func logInterpolationsDeclarePrivacy() {
        let calls: [String] = [".debug(\"", ".info(\"", ".notice(\"", ".error(\"", ".fault(\"", ".warning(\""]
        var offenders: [String] = []
        for file in Self.files(in: ["SSHApp"], extensions: ["swift"]) {
            for (number, line) in Self.lines(file).enumerated() where calls.contains(where: { line.contains($0) }) {
                let interpolations: Int = line.components(separatedBy: "\\(").count - 1
                let privacy: Int = line.components(separatedBy: "privacy:").count - 1
                if interpolations != privacy {
                    offenders.append("\(Self.relative(file)):\(number + 1)")
                }
            }
        }
        #expect(offenders.isEmpty, "Hostnamen/Benutzer nur mit .private(mask: .hash), Aufruf in einer Zeile (S9): \(offenders)")
    }
}
