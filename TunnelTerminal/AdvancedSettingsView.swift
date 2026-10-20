import SwiftUI

/// Einstellungen › Erweitert (Plan M7): Standard-App für Links, eingebaute PuTTY-Version mit Update-Hinweis (S7) und
/// die Ordner der App im Finder.
struct AdvancedSettingsView: View {
    @State private var model: AdvancedSettingsModel = AdvancedSettingsModel()

    var body: some View {
        Form {
            Section {
                ForEach(AdvancedSettingsModel.schemes, id: \.self) { scheme in
                    LabeledContent("\(scheme)://", value: model.handlers[scheme] ?? "keine")
                }
                Button("\(AppIdentity.name) als Standard festlegen", action: makeDefault)
                    .disabled(model.isDefaultHandler)
                if let failure = model.failure {
                    ErrorText(failure)
                }
            } header: {
                Text("Standard-App für Links")
            } footer: {
                Text("Öffnest du einen solchen Link, etwa in Safari, startet diese App und fragt vor dem Verbinden nach.")
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Eingebaute Version", value: model.puttyRelease.map { "PuTTY \($0)" } ?? "unbekannt")
                // Knopf statt Link: Link-Text in der Akzentfarbe hätte im Dunkelmodus zu wenig Kontrast (Prüfer M7)
                LabeledContent("Neue Versionen und Sicherheitshinweise") {
                    Button("PuTTY-Website öffnen") { NSWorkspace.shared.open(PuTTYInfo.website) }
                }
            } header: {
                Text("PuTTY")
            } footer: {
                Text(PuTTYInfo.updateNote)
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Sitzungen und Hostschlüssel") {
                    Button("Im Finder zeigen", action: model.revealPuTTYFolder)
                        .accessibilityLabel("Ordner der Sitzungen und Hostschlüssel im Finder zeigen")
                }
                LabeledContent("Sitzungsprotokolle") {
                    Button("Im Finder zeigen", action: model.revealSessionLogs)
                        .accessibilityLabel("Ordner der Sitzungsprotokolle im Finder zeigen")
                        .disabled(!model.hasSessionLogs)
                }
            } header: {
                Text("Ordner")
            } footer: {
                Text("Änderungen gelten sofort.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .task { await model.load() }
        // Die Standard-App kann sich auch außerhalb ändern (z. B. eine andere App legt sich fest)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshHandlers()
        }
    }

    private func makeDefault() {
        Task { await model.makeDefaultHandler() }
    }
}
