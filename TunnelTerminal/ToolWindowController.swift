import AppKit
import SwiftUI

/// Eigenes Fenster für Schlüssel bzw. bekannte Hostschlüssel (je eines für die ganze App, Plan M3).
/// `onBecomeKey` läuft, wenn das Fenster nach vorne kommt (z. B. Liste neu lesen).
final class ToolWindowController: NSWindowController, NSWindowDelegate {
    var onBecomeKey: (() -> Void)?

    init<Content: View>(title: String, autosaveName: String, rootView: Content) {
        let hosting: NSHostingController<Content> = NSHostingController(rootView: rootView)
        hosting.sizingOptions = [.minSize]   // Mindestgröße aus dem Inhalt, sonst frei (Richtlinien 3.4 Regel 19)
        let window: NSWindow = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isRestorable = false
        window.setFrameAutosaveName(autosaveName)
        super.init(window: window)
        window.delegate = self
        if window.frame.origin == .zero { window.center() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht benutzt") }

    func windowDidBecomeKey(_ notification: Notification) {
        onBecomeKey?()
    }
}
