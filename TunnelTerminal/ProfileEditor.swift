import AppKit
import SwiftUI
import TunnelTerminalCore

/// Ein Profil bearbeiten; jede gültige Änderung gilt sofort (auch in offenen Tabs).
struct ProfileEditor: View {
    let store: ProfileStore
    @State private var draft: TerminalProfile
    @State private var error: String?

    /// Festbreitenschriften des Systems (PostScript-Name, Anzeigename), einmal je Programmlauf ermittelt.
    private static let fonts: [(name: String, title: String)] = {
        let names: [String] = NSFontManager.shared.availableFontNames(with: .fixedPitchFontMask) ?? []
        return names.map { ($0, NSFont(name: $0, size: 13)?.displayName ?? $0) }.sorted { $0.title < $1.title }
    }()

    init(store: ProfileStore, profile: TerminalProfile) {
        self.store = store
        _draft = State(initialValue: profile)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $draft.name)
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            Section("Schrift") {
                Picker("Schrift", selection: $draft.fontName) {
                    Text("Systemschrift (SF Mono)").tag("")
                    if !draft.fontName.isEmpty && !Self.fonts.contains(where: { $0.name == draft.fontName }) {
                        Text("\(draft.fontName) (nicht installiert)").tag(draft.fontName)
                    }
                    ForEach(Self.fonts, id: \.name) { font in
                        Text(font.title).tag(font.name)
                    }
                }
                LabeledContent("Größe (pt)") {
                    HStack {
                        TextField("Größe", value: $draft.fontSize, format: .number)
                            .labelsHidden()
                            .frame(width: 56)
                        Stepper("Größe", value: $draft.fontSize, in: TerminalProfile.fontSizes)
                            .labelsHidden()
                    }
                }
            }
            Section("Farben, Cursor, Glocke") {
                Picker("Farbschema", selection: $draft.colorScheme) {
                    ForEach(TerminalProfile.ColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.title)
                    }
                }
                Picker("Cursor", selection: $draft.cursorShape) {
                    ForEach(TerminalProfile.CursorShape.allCases, id: \.self) { shape in
                        Text(shape.title)
                    }
                }
                Picker("Glocke", selection: $draft.bell) {
                    ForEach(TerminalProfile.Bell.allCases, id: \.self) { bell in
                        Text(bell.title)
                    }
                }
            }
            Section {
                LabeledContent("Rückblättern (Zeilen)") {
                    TextField("Zeilen", value: $draft.scrollbackLines, format: .number)
                        .labelsHidden()
                        .frame(width: 90)
                }
            } footer: {
                Text("Bis \(TerminalProfile.scrollbackRange.upperBound.formatted()) Zeilen. Änderungen gelten sofort, auch in offenen Tabs.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .autocorrectionDisabled()
        .onChange(of: draft) { save() }
    }

    private func save() {
        do {
            try store.update(draft)
            error = nil
            // Werte außerhalb des Bereichs zeigt das Feld so, wie sie gelten
            let saved: TerminalProfile = store.profile(id: draft.id)
            if saved != draft { draft = saved }
        } catch {
            self.error = error.message
        }
    }
}
