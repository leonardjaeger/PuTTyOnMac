import SwiftUI
import TunnelTerminalCore

/// Abschnitt „Seriell“ im Sitzungs-Editor (Plan M5): Gerät aus /dev/cu.*, Geschwindigkeit, Datenbits, Stoppbits,
/// Parität, Flusskontrolle – nur die Werte, die plink unter macOS umsetzt (docs/M5-Machbarkeit.md 3).
struct SerialEditorSection: View {
    let file: SessionFile
    let apply: ((inout SessionFile) throws -> Void) -> String?

    @State private var devices: [String] = []
    @State private var line: String
    @State private var speed: Int
    @State private var dataBits: Int
    @State private var stopBits: Int
    @State private var parity: SerialParity?
    @State private var flow: SerialFlowControl?
    @State private var problem: String?

    /// Werte im `init` übernehmen, nicht in `onAppear`: sonst schriebe schon das Öffnen Vorgaben in die Datei.
    init(file: SessionFile, apply: @escaping ((inout SessionFile) throws -> Void) -> String?) {
        self.file = file
        self.apply = apply
        _line = State(initialValue: file.serialLine)
        _speed = State(initialValue: file.serialSpeed)
        _dataBits = State(initialValue: file.serialDataBits)
        _stopBits = State(initialValue: file.serialStopBits)
        _parity = State(initialValue: file.serialParity)
        _flow = State(initialValue: file.serialFlowControl)
    }

    private static let speeds: [Int] = [300, 1200, 2400, 4800, 9600, 19_200, 38_400, 57_600, 115_200, 230_400, 460_800, 921_600]

    var body: some View {
        Section {
            Picker("Gerät", selection: $line) {
                if !devices.contains(line) {
                    Text(line.isEmpty ? "Gerät wählen" : SessionWarning.visible(line)).tag(line)
                }
                ForEach(devices, id: \.self) { device in
                    Text(device).tag(device)
                }
            }
            HStack {
                if devices.isEmpty {
                    Text("Kein serielles Gerät gefunden – Adapter anschließen.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Geräte neu suchen", action: findDevices)
            }
            Picker("Geschwindigkeit (Baud)", selection: $speed) {
                ForEach(Self.speeds.contains(speed) ? Self.speeds : Self.speeds + [speed], id: \.self) { value in
                    Text(String(value)).tag(value)
                }
            }
            Picker("Datenbits", selection: $dataBits) {
                ForEach(5...8, id: \.self) { Text(String($0)).tag($0) }
            }
            Picker("Stoppbits", selection: $stopBits) {
                Text("1").tag(1)
                Text("2").tag(2)
            }
            Picker("Parität", selection: $parity) {
                ForEach(SerialParity.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                if parity == nil { Text("Andere (wirkt unter macOS wie keine)").tag(SerialParity?.none) }
            }
            Picker("Flusskontrolle", selection: $flow) {
                ForEach(SerialFlowControl.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                if flow == nil { Text("Andere (wirkt unter macOS wie keine)").tag(SerialFlowControl?.none) }
            }
            ErrorText(problem)
        } header: {
            Text("Seriell")
        } footer: {
            Text("Zeichen gehen sofort an das Gerät, das Echo kommt vom Gerät. Trennen mit ⌘.")
                .foregroundStyle(.secondary)
        }
        .onAppear(perform: findDevices)
        .onChange(of: line) { _, new in
            guard !new.isEmpty else { return }
            problem = apply { try $0.setSerialLine(new) }
        }
        .onChange(of: speed) { _, new in problem = apply { try $0.setSerialSpeed(new) } }
        .onChange(of: dataBits) { _, new in problem = apply { try $0.setSerialDataBits(new) } }
        .onChange(of: stopBits) { _, new in problem = apply { try $0.setSerialStopBits(new) } }
        .onChange(of: parity) { _, new in
            if let new { problem = apply { $0.setSerialParity(new) } }
        }
        .onChange(of: flow) { _, new in
            if let new { problem = apply { $0.setSerialFlowControl(new) } }
        }
    }

    /// Nur die „cu.“-Geräte: Sie öffnen ohne auf ein Trägersignal zu warten (anders als „tty.“).
    private func findDevices() {
        let names: [String] = (try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? []
        devices = names.filter { $0.hasPrefix("cu.") }.sorted().map { "/dev/" + $0 }
    }
}
