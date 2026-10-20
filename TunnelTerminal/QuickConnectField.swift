import SwiftUI
import TunnelTerminalCore

/// Feld „Schnellverbindung“ oben in der Seitenleiste; Return verbindet (⇧⌘K setzt den Fokus).
struct QuickConnectField: View {
    @Bindable var quick: QuickConnect
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Schnellverbindung", text: $quick.address, prompt: Text("benutzer@server:port"))
                .textFieldStyle(.roundedBorder)
                .monospaced()
                .autocorrectionDisabled()
                .labelsHidden()
                .focused($focused)
                .onSubmit(quick.submit)
                .help("Adresse eingeben und Return drücken (⇧⌘K)")
            Picker("Protokoll", selection: $quick.connectionProtocol) {
                ForEach(ConnectionProtocol.quickConnectCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if let message = quick.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .onChange(of: quick.address) { quick.errorMessage = nil }
        .onChange(of: quick.focusRequests) { focused = true }
        .onAppear { focused = quick.focusRequests > 0 }
    }
}
