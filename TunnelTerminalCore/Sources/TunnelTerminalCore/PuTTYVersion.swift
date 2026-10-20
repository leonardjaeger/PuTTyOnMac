/// Eingebaute PuTTY-Version aus der Ausgabe von `plink -V` (Plan M7, S7); erste Zeile z. B. „plink: Release 0.85“.
public enum PuTTYVersion {
    /// „0.85“, oder `nil`, wenn die erste Zeile keine Release-Angabe enthält (z. B. ein Entwicklungsstand).
    public static func release(fromVersionOutput output: String) -> String? {
        // „<Programm>: Release <Version>“; der Programmname hat keine Leerzeichen (anders als „Build platform: …“)
        guard let line = output.split(whereSeparator: \.isNewline).first,
              let range = line.range(of: ": Release "), !line[..<range.lowerBound].contains(" ") else { return nil }
        let version: Substring = line[range.upperBound...].prefix { $0.isASCII && ($0.isNumber || $0 == ".") }
        return version.first?.isNumber == true ? String(version) : nil
    }
}
