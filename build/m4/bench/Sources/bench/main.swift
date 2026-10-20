import Foundation
import SwiftTerm

final class Sink: TerminalDelegate {
    func send(source: Terminal, data: ArraySlice<UInt8>) {}
}
var payload: [UInt8] = []
for number in 1...1_000_000 { payload.append(contentsOf: "Zeile \(number)\n".utf8) }
let terminal: Terminal = Terminal(delegate: Sink(), options: TerminalOptions(cols: 120, rows: 40, scrollback: 2_000))
let start: Date = .now
var offset: Int = 0
while offset < payload.count {
    let end: Int = min(offset + 16_384, payload.count)
    terminal.feed(byteArray: Array(payload[offset..<end]))
    offset = end
}
let seconds: Double = Date.now.timeIntervalSince(start)
print("SwiftTerm-Parser: \(String(format: "%.1f", Double(payload.count) / 1e6)) MB in \(String(format: "%.2f", seconds)) s = \(String(format: "%.1f", Double(payload.count) / 1e6 / seconds)) MB/s")
