import Testing
@testable import TunnelTerminalCore

/// Hilfe › PuTTY-Version (Plan M7, S7): Version aus der Ausgabe von `plink -V`.
@Suite("PuTTY-Version")
struct PuTTYVersionTests {
    @Test("Release-Zeile von plink 0.85")
    func release() {
        let output: String = "plink: Release 0.85\nBuild platform: 64-bit Unix\nCompiler: clang 17.0.0\n"
        #expect(PuTTYVersion.release(fromVersionOutput: output) == "0.85")
    }

    @Test("Ohne Release-Angabe in der ersten Zeile: nil", arguments: [
        "", "plink: Development snapshot 2026-10-01.abcdef\n", "Build platform: Release 0.85\n", "plink: Release x\n"
    ])
    func noRelease(output: String) {
        #expect(PuTTYVersion.release(fromVersionOutput: output) == nil)
    }
}
