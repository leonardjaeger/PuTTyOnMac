import SwiftUI
import TunnelTerminalCore

/// Einstellungen › Profile (Plan M4): links die Liste, rechts das gewählte Profil. „+“ legt eine Kopie des gewählten an;
/// das Standardprofil lässt sich ändern, aber nicht entfernen.
struct ProfilesSettingsView: View {
    let store: ProfileStore
    @State private var selection: UUID? = TerminalProfile.standardID

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(store.profiles, selection: $selection) { profile in
                    Text(SessionWarning.visible(profile.name))
                }
                Divider()
                HStack {
                    Button("Profil hinzufügen (Kopie des gewählten)", systemImage: "plus", action: add)
                    Button("Profil entfernen", systemImage: "minus", action: remove)
                        .disabled(selection == nil || selection == TerminalProfile.standardID)
                    Spacer()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(width: 190)
            Divider()
            if let profile = store.profiles.first(where: { $0.id == selection }) {
                ProfileEditor(store: store, profile: profile)
                    .id(profile.id)
            } else {
                ContentUnavailableView("Kein Profil gewählt", systemImage: "paintpalette")
            }
        }
        .frame(width: 680, height: 470)
    }

    private func add() {
        selection = store.add(copying: store.profile(id: selection)).id
    }

    private func remove() {
        guard let selection else { return }
        store.remove(id: selection)
        self.selection = TerminalProfile.standardID
    }
}
