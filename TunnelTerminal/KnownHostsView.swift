import SwiftUI
import TunnelTerminalCore

/// Fenster „Bekannte Hostschlüssel“ (Plan M3, Oberfläche 3.1): Server, Port, Typ, Fingerabdruck; Einträge entfernen.
struct KnownHostsView: View {
    @Bindable var model: KnownHostsModel

    var body: some View {
        VStack(spacing: 0) {
            Table(model.entries, selection: $model.selection) {
                TableColumn("Server") { entry in Text(SessionWarning.visible(entry.host)).monospaced() }
                TableColumn("Port") { entry in Text(String(entry.port)).monospacedDigit() }
                    .width(min: 44, ideal: 56, max: 80)
                TableColumn("Typ") { entry in Text(SessionWarning.visible(entry.typeTitle)) }
                    .width(min: 70, ideal: 100, max: 140)
                TableColumn("Fingerabdruck") { entry in
                    Text(entry.fingerprint ?? "nicht lesbar")
                        .monospaced()
                        .textSelection(.enabled)
                        .foregroundStyle(entry.fingerprint == nil ? .secondary : .primary)
                        .help(entry.fingerprint ?? "")
                }
                .width(min: 410, ideal: 420)   // SHA256-Fingerabdruck ungekürzt (50 Zeichen)
            }
            .onDeleteCommand(perform: model.requestRemoval)
            .overlay {
                if model.entries.isEmpty {
                    ContentUnavailableView("Keine bekannten Hostschlüssel", systemImage: "checkmark.shield",
                                           description: Text("Beim ersten Verbinden mit einem Server zeigt plink dessen Fingerabdruck und fragt, ob es ihn sich merken soll."))
                }
            }
            Divider()
            HStack {
                Button("Entfernen …", systemImage: "minus", action: model.requestRemoval)
                    .disabled(model.selection.isEmpty)
                if let failure = model.failure {
                    Label(failure, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                Spacer()
                Text("Nach dem Entfernen fragt plink beim nächsten Verbinden wieder.")
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
        .frame(minWidth: 760, idealWidth: 820, minHeight: 300, idealHeight: 420)
        .confirmationDialog(removalTitle, isPresented: $model.isConfirmingRemoval) {
            Button("Entfernen", role: .destructive, action: model.removeSelection)
        } message: {
            Text("Beim nächsten Verbinden zeigt plink den Fingerabdruck erneut. Vergleiche ihn dann mit dem des Servers – ein unerwarteter Wechsel kann auf einen Angriff hindeuten.")
        }
    }

    private var removalTitle: String {
        model.selection.count == 1 ? "Hostschlüssel entfernen?" : "\(model.selection.count) Hostschlüssel entfernen?"
    }
}
