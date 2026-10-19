import SwiftUI

/// Unten in der Seitenleiste (Plan 3.1): „Schlüssel“ und „Bekannte Hostschlüssel“ (M3), darunter Sitzung anlegen und
/// die ausgewählte bearbeiten – sichtbare Wege neben Menü und Kontextmenü.
struct SidebarFooter: View {
    let model: SessionsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider()
                .padding(.bottom, 4)
            Button("Schlüssel", systemImage: "key", action: showKeys)
            Button("Bekannte Hostschlüssel", systemImage: "checkmark.shield", action: showKnownHosts)
            SessionButtons(model: model)
        }
        .buttonStyle(.borderless)
    }

    private func showKeys() {
        NSApp.sendAction(#selector(AppDelegate.showKeys(_:)), to: nil, from: nil)
    }

    private func showKnownHosts() {
        NSApp.sendAction(#selector(AppDelegate.showKnownHosts(_:)), to: nil, from: nil)
    }
}

/// Neue Sitzung und Bearbeiten als Symbolknöpfe.
private struct SessionButtons: View {
    let model: SessionsModel

    var body: some View {
        HStack(spacing: 4) {
            Button("Neue Sitzung", systemImage: "plus", action: model.newSession)
                .frame(width: 28, height: 28)
                .contentShape(.rect)
                .help("Neue Sitzung (⇧⌘N)")
            Button("Sitzung bearbeiten …", systemImage: "pencil", action: model.editSelection)
                .frame(width: 28, height: 28)
                .contentShape(.rect)
                .help("Ausgewählte Sitzung bearbeiten")
                .disabled(model.selection.count != 1)
            Spacer()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .imageScale(.large)
        .padding(.bottom, 6)
    }
}
