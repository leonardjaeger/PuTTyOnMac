import SwiftUI
import TunnelTerminalCore

/// Vorschau vor dem Import: was übernommen wird, mit Warnungen (Plan S4). Gefährliches ist nicht vorausgewählt.
struct ImportPreviewView: View {
    @Bindable var preview: ImportPreview
    let cancel: () -> Void
    let confirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sitzungen aus „\(SessionWarning.visible(preview.source))“ importieren")
                .font(.headline)
            if preview.candidates.isEmpty {
                ContentUnavailableView("Keine Sitzungen gefunden", systemImage: "tray",
                                       description: Text("Die Quelle enthält keine PuTTY-Sitzungen."))
            } else {
                List(preview.candidates) { candidate in
                    ImportCandidateRow(candidate: candidate, isChosen: $preview.chosen[candidate.id])
                }
                .listStyle(.bordered(alternatesRowBackgrounds: true))
            }
            if !preview.unreadable.isEmpty {
                Label("Nicht lesbar und übersprungen: \(SessionWarning.visible(preview.unreadable.joined(separator: ", ")))",
                      systemImage: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Importieren", action: confirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(preview.chosenCandidates.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 560, idealWidth: 620, minHeight: 380, idealHeight: 460)
    }
}

private struct ImportCandidateRow: View {
    let candidate: ImportCandidate
    @Binding var isChosen: Bool

    var body: some View {
        Toggle(isOn: $isChosen) {
            VStack(alignment: .leading, spacing: 4) {
                Text(SessionWarning.visible(candidate.name))
                    .bold()
                if candidate.name != candidate.originalName {
                    Text("In der Quelle: „\(SessionWarning.visible(candidate.originalName))“ (Name schon vergeben)")
                        .foregroundStyle(.secondary)
                }
                if let problem = candidate.problem {
                    Label("Wird nicht importiert: \(problem.message)", systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                }
                if candidate.replacesDefaultSettings {
                    Label("Ersetzt die eigenen Standardeinstellungen.", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(candidate.warnings.enumerated()), id: \.offset) { _, warning in
                    Label(warning.message, systemImage: warning.isDangerous ? "exclamationmark.triangle.fill" : "info.circle")
                        .foregroundStyle(warning.isDangerous ? Color.orange : Color.secondary)
                }
                ForEach(candidate.notes, id: \.self) { note in
                    Text(SessionWarning.visible(note))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(candidate.problem != nil)
        .padding(.vertical, 2)
    }
}
