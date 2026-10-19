import SwiftUI
import TunnelTerminalCore

/// Editor einer Sitzung als Sheet am Hauptfenster (Plan 3.1). Änderungen sind sofort gespeichert, deshalb nur „Fertig“
/// (auch Esc). Nach einem Umbenennen bleibt das Sheet offen und zeigt die Sitzung unter dem neuen Namen.
struct SessionEditorSheet: View {
    let model: SessionsModel
    let editing: SessionsModel.EditedSession

    var body: some View {
        let name: String = model.editing?.name ?? editing.name
        VStack(spacing: 0) {
            if let file = model.editableFile(named: name) {
                SessionEditor(model: model, name: name, file: file)
                    .id("\(name)#\(model.library.revision)")
            } else {
                ContentUnavailableView("Sitzung nicht gefunden", systemImage: "questionmark.folder")
            }
            Divider()
            HStack {
                if name != SessionName.defaultSettings {
                    Button("Verbinden") { connect(name) }
                }
                Spacer()
                Button("Fertig", action: close)
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 460, idealHeight: 620)
    }

    /// Verbindet erst nach dem Schließen (`SessionsModel.connectAfterEditing`): Ein noch nicht bestätigter Name wird beim
    /// Schließen übernommen, plink soll die Sitzung unter dem neuen Namen laden.
    private func connect(_ name: String) {
        model.pendingConnection = name
        close()
    }

    private func close() {
        model.editing = nil
    }
}
