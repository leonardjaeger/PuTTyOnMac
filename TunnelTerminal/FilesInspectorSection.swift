import SwiftUI
import TunnelTerminalCore

/// Inspektor-Abschnitt „Dateien“ (Plan 3.1, M6): Ablagefläche zum Hochladen, „Herunterladen …“, Fortschritt mit
/// „Abbrechen“ und das Ergebnis der letzten Übertragung. Nur bei SSH (pscp spricht nur SSH), bedienbar nur während der
/// Verbindung (Plan M6).
struct FilesInspectorSection: View {
    let model: FileTransferModel
    let isConnected: Bool

    @State private var isTargeted: Bool = false

    var body: some View {
        Section("Dateien") {
            if let activity = model.activity {
                VStack(alignment: .leading, spacing: 6) {
                    Text(activity)
                    if let fraction = model.fraction {
                        ProgressView(value: fraction)
                            .accessibilityValue("\(Int(fraction * 100)) Prozent")
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button("Abbrechen", systemImage: "xmark.circle", action: cancel)
                }
            } else {
                Button(action: chooseFiles) {
                    Label("Zum Hochladen Dateien hierher ziehen oder klicken – den Zielordner wählst du danach",
                          systemImage: "arrow.up.doc")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 8)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .background(isTargeted ? Color.accentColor.opacity(0.15) : Color.clear, in: .rect(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.5),
                                              style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .labelStyle(.titleAndIcon)
                .disabled(!isConnected)
                .help("Dateien auf den Server hochladen")
                .dropDestination(for: URL.self) { urls, _ in
                    drop(urls)
                } isTargeted: { targeted in
                    isTargeted = targeted
                }
                Button("Herunterladen …", systemImage: "arrow.down.doc", action: download)
                    .disabled(!isConnected)
                    .help("Eine Datei vom Server auf diesen Mac laden")
                if !isConnected {
                    Text("Nur während einer Verbindung.")
                        .foregroundStyle(.secondary)
                }
            }
            if let result = model.result, model.resultIsError {
                ErrorText(result)
                    .textSelection(.enabled)
            } else if let result = model.result {
                Label(result, systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let downloaded = model.downloaded {
                Button("Im Finder zeigen", systemImage: "folder") { reveal(downloaded) }
            }
        }
    }

    private func drop(_ urls: [URL]) -> Bool {
        let files: [URL] = urls.filter(\.isFileURL)
        guard isConnected, !files.isEmpty else { return false }
        model.upload?(files)
        return true
    }

    private func chooseFiles() { model.chooseFiles?() }

    private func download() { model.download?() }

    private func cancel() { model.cancel?() }

    private func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
