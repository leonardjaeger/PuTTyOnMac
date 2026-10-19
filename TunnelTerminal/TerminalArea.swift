import AppKit

/// Mittlerer Bereich des Hauptfensters: oben ggf. ein Hinweis (Verbindungsende), darunter Startansicht oder Terminal.
/// Beginnt unter der Symbolleiste (sicherer Bereich), weil das Fenster bis unter die Titelleiste reicht.
final class TerminalArea: NSViewController {
    private var banner: NSView?
    private var content: NSView?
    private var constraints: [NSLayoutConstraint] = []

    override func loadView() {
        view = NSView()
    }

    func show(_ newContent: NSView) {
        content?.removeFromSuperview()
        content = newContent
        add(newContent)
    }

    func showBanner(_ newBanner: NSView?) {
        banner?.removeFromSuperview()
        banner = newBanner
        if let newBanner { add(newBanner) } else { relayout() }
    }

    private func add(_ subview: NSView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)
        relayout()
    }

    private func relayout() {
        NSLayoutConstraint.deactivate(constraints)
        constraints = []
        var top: NSLayoutYAxisAnchor = view.safeAreaLayoutGuide.topAnchor
        for subview in [banner, content].compactMap({ $0 }) {
            constraints += [subview.topAnchor.constraint(equalTo: top),
                            subview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                            subview.trailingAnchor.constraint(equalTo: view.trailingAnchor)]
            top = subview.bottomAnchor
        }
        if let content { constraints.append(content.bottomAnchor.constraint(equalTo: view.bottomAnchor)) }
        NSLayoutConstraint.activate(constraints)
    }
}
