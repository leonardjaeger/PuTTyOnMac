import TunnelTerminalCore
import SwiftUI

/// Schnellverbindung: Adresse „benutzer@server:port“ und Protokoll (Plan M1).
struct ConnectForm: View {
    /// Liefert eine Fehlermeldung oder `nil`, wenn die Verbindung startet.
    let connect: (String, ConnectionProtocol) -> String?

    @State private var address: String = ""
    @State private var connectionProtocol: ConnectionProtocol = .ssh
    @State private var errorMessage: String?
    @FocusState private var addressFocused: Bool

    /// `address` und `connectionProtocol` belegen das Formular vor (neuer Tab neben einer Verbindung).
    init(address: String = "", connectionProtocol: ConnectionProtocol = .ssh,
         connect: @escaping (String, ConnectionProtocol) -> String?) {
        self.connect = connect
        _address = State(initialValue: address)
        _connectionProtocol = State(initialValue: connectionProtocol)
    }

    var body: some View {
        Form {
            Section {
                TextField("Adresse", text: $address, prompt: Text("benutzer@server.example:22"))
                    .autocorrectionDisabled()
                    .focused($addressFocused)
                    .onSubmit(submit)
                Picker("Protokoll", selection: $connectionProtocol) {
                    ForEach(ConnectionProtocol.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } header: {
                Text("Schnellverbindung")
            } footer: {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            HStack {
                Spacer()
                Button("Verbinden", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 480, maxHeight: 260)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { addressFocused = true }
    }

    private func submit() {
        errorMessage = connect(address, connectionProtocol)
    }
}
