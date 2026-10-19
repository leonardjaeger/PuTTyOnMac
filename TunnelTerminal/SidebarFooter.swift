import SwiftUI

/// Leiste unten in der Seitenleiste: Sitzung anlegen und die ausgewählte bearbeiten – sichtbare Wege neben Menü und
/// Kontextmenü (Plan 3.1; ab M3 kommen hier „Schlüssel“ und „Bekannte Hostschlüssel“ dazu).
struct SidebarFooter: View {
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
