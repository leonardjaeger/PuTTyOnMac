import SwiftUI
import TunnelTerminalCore

/// Seitenleiste des Hauptfensters (Plan 3.1): oben die Schnellverbindung, darunter die gespeicherten Sitzungen nach
/// Gruppen mit Status. Doppelklick verbindet. Editor, Importvorschau und Fehlermeldungen erscheinen als Sheet am Fenster.
struct SessionSidebar: View {
    @Bindable var model: SessionsModel
    let quick: QuickConnect
    let connected: ConnectedSessions

    var body: some View {
        let groups: [SessionLibrary.Group] = model.library.groups(matching: model.search)
        VStack(spacing: 8) {
            QuickConnectField(quick: quick)
            TextField("Sitzungen durchsuchen", text: $model.search, prompt: Text("Name oder Server"))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .autocorrectionDisabled()
            List(selection: $model.selection) {
                if model.search.isEmpty {
                    Section {
                        Label("Standardeinstellungen", systemImage: "slider.horizontal.3")
                            .tag(SessionName.defaultSettings)
                    }
                }
                ForEach(groups) { group in
                    Section(group.title ?? "Ohne Gruppe") {
                        ForEach(group.names, id: \.self) { name in
                            SessionRow(title: SessionWarning.visible(SessionName.title(of: name)),
                                       host: SessionWarning.visible(model.library.host(of: name)),
                                       protocolTitle: model.library.connectionProtocol(of: name)?.title,
                                       isConnected: connected.contains(name))
                                .tag(name)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .contextMenu(forSelectionType: String.self) { names in
                Button("Verbinden") { model.connect(names) }
                    .disabled(names.allSatisfy { $0 == SessionName.defaultSettings })
                Button("Bearbeiten …") {
                    model.selection = names
                    model.editSelection()
                }
                .disabled(names.count != 1)
                Button("Duplizieren") {
                    model.selection = names
                    model.duplicateSelection()
                }
                Divider()
                Button("Löschen", role: .destructive) {
                    model.selection = names
                    model.deleteSelection()
                }
            } primaryAction: { names in
                model.connect(names)
            }
            .overlay {
                if groups.isEmpty && !model.search.isEmpty {
                    ContentUnavailableView.search(text: model.search)
                }
            }
            SidebarFooter(model: model)
        }
        .padding(.top, 8)
        .padding(.horizontal, 10)
        .onChange(of: model.library.revision) { model.dropMissingSelection() }
        .sheet(item: $model.editing, onDismiss: model.connectAfterEditing) { editing in
            SessionEditorSheet(model: model, editing: editing)
        }
        .sheet(item: $model.importPreview) { preview in
            ImportPreviewView(preview: preview, cancel: { model.importPreview = nil }, confirm: model.finishImport)
        }
        .alert("Aktion nicht möglich", isPresented: $model.isShowingFailure, presenting: model.failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure.message)
        }
    }
}
