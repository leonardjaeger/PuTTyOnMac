import AppKit
import TunnelTerminalCore

/// Was Menü und Symbolleiste eines Tabs gerade erlauben (M7 aus dem Fenster-Controller herausgelöst): Der Controller
/// füllt den Zustand aus seinen privaten Teilen, die Regeln stehen hier und lassen sich ohne Fenster prüfen. Die
/// Symbolleisten-Knöpfe haben die Aktionen der Menübefehle und laufen durch dieselben Regeln.
struct TabCommandState {
    var hasSheet: Bool = false
    var isConnected: Bool = false
    var hasConnection: Bool = false
    var hasTerminal: Bool = false
    var canTransfer: Bool = false
    var canEditTunnels: Bool = false
    var isTransferring: Bool = false
    var sessionListHasFocus: Bool = false
    var savedSelection: [String] = []
    var selectionCount: Int = 0
    var hasConnectableSelection: Bool = false
    var hasSavedSessions: Bool = false

    func allows(_ action: Selector?) -> Bool {
        // Bei offenem Sheet (Editor, Rückfrage, Dialog) erreichen Menübefehle dieses Fenster weiter über das
        // Hauptfenster: nur Trennen bleibt
        if hasSheet { return action == #selector(ConnectionWindowController.disconnect(_:)) && isConnected }
        return switch action {
        case #selector(ConnectionWindowController.reconnect(_:)): hasConnection && !isConnected   // erst, wenn plink beendet ist
        case #selector(ConnectionWindowController.disconnect(_:)): isConnected
        case #selector(ConnectionWindowController.deleteSessions(_:)): sessionListHasFocus && !savedSelection.isEmpty
        case #selector(ConnectionWindowController.duplicateSessions(_:)):
            !savedSelection.contains(SessionName.defaultSettings) && !savedSelection.isEmpty
        case #selector(ConnectionWindowController.editSession(_:)): selectionCount == 1
        case #selector(ConnectionWindowController.connectSessions(_:)): hasConnectableSelection
        case #selector(ConnectionWindowController.exportRegistry(_:)),
             #selector(ConnectionWindowController.exportFolder(_:)): hasSavedSessions
        case #selector(ConnectionWindowController.clearScreenAndHistory(_:)),
             #selector(ConnectionWindowController.copyEverything(_:)),
             #selector(NSResponder.performTextFinderAction(_:)): hasTerminal
        case #selector(ConnectionWindowController.duplicateConnection(_:)): hasConnection
        case #selector(ConnectionWindowController.editTunnels(_:)): canEditTunnels
        case #selector(ConnectionWindowController.uploadFiles(_:)),
             #selector(ConnectionWindowController.downloadFile(_:)): canTransfer
        case #selector(ConnectionWindowController.cancelTransfer(_:)): isTransferring
        default: true
        }
    }

}
