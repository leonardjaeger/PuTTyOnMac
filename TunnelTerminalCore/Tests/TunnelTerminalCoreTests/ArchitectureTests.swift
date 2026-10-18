import Foundation
import Testing

/// Grundsatz-Tests (fitness functions): Regeln aus Plan Abschnitt 3 und 6, die sonst nur als Text gelten.
/// Schlägt einer an, sagt die Meldung, welche Datei die Regel bricht und wo die Regel steht.
@Suite("Grundsätze")
struct ArchitectureTests {
    /// Wurzel des Repos aus dem Pfad dieser Datei (TunnelTerminalCore/Tests/TunnelTerminalCoreTests/…).
    private static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Ausgelieferter Code: App und Kern (ohne Tests) sowie die Bauskripte.
    private static let shippedFolders: [String] = ["TunnelTerminal", "TunnelTerminalCore/Sources", "Scripts"]

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

    /// Alle Dateien des Repos laut Git (eingecheckt oder neu, ohne Ignoriertes), relativ zur Wurzel.
    private static func repoFiles() throws -> [String] {
        let git: Process = Process()
        git.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        git.arguments = ["-C", root.path, "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
        let pipe: Pipe = Pipe()
        git.standardOutput = pipe
        try git.run()
        let data: Data = pipe.fileHandleForReading.readDataToEndOfFile()
        git.waitUntilExit()
        try #require(git.terminationStatus == 0, "git ls-files ist fehlgeschlagen")
        return String(decoding: data, as: UTF8.self).split(separator: "\0").map(String.init)
    }

    private static func relative(_ url: URL) -> String {
        String(url.path.dropFirst(root.path.count + 1))
    }

    @Test("Die Suche findet Quelltext (sonst prüfen die übrigen Tests nichts)")
    func scannerFindsSources() {
        #expect(Self.files(in: ["TunnelTerminalCore/Sources"], extensions: ["swift"]).count >= 4)
        #expect(Self.files(in: ["TunnelTerminal"], extensions: ["swift"]).count >= 4)
        #expect(Self.files(in: ["Scripts"], extensions: ["sh"]).count >= 1)
    }

    @Test("Der Kern importiert kein AppKit, SwiftUI, Cocoa oder SwiftTerm (Plan 3)")
    func coreHasNoUIImports() {
        let forbidden: Set<String> = ["import AppKit", "import SwiftUI", "import Cocoa", "import SwiftTerm"]
        var offenders: [String] = []
        for file in Self.files(in: ["TunnelTerminalCore/Sources"], extensions: ["swift"]) {
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
        for file in Self.files(in: ["TunnelTerminal"], extensions: ["swift"]) {
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

    @Test("Der alte Arbeitstitel kommt im Repo nicht mehr vor – nur im Verlauf der Prüflisten M0/M1 (U1)")
    func noOldWorkingTitle() throws {
        // Muster zusammengesetzt, damit diese Datei sich nicht selbst findet; trifft den alten Namen mit Bindestrich, Unterstrich, Leerzeichen oder zusammengeschrieben, in jeder Schreibweise
        let regex: NSRegularExpression = try NSRegularExpression(pattern: "ssh" + "[-_ ]?" + "app", options: [.caseInsensitive])
        let files: [String] = try Self.repoFiles()
        #expect(files.count >= 50, "Die Suche muss das ganze Repo sehen")
        var offenders: [String] = []
        for path in files where !path.hasPrefix("docs/M0-") && !path.hasPrefix("docs/M1-") {
            // fehlertolerant dekodiert (ungültige Bytes werden ersetzt), damit auch Nicht-UTF-8-Dateien geprüft werden
            let data: Data = (try? Data(contentsOf: Self.root.appendingPathComponent(path))) ?? Data()
            let text: String = path + "\n" + String(decoding: data, as: UTF8.self)
            for (number, line) in text.components(separatedBy: "\n").enumerated()
            where regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
                offenders.append(number == 0 ? "\(path) (Dateiname)" : "\(path):\(number)")
            }
        }
        #expect(offenders.isEmpty, "App heißt TunnelTerminal (U1): \(offenders)")
    }
}
