import AppKit

/// Hilfe › Kurzanleitung (Plan M7): `Kurzanleitung.rtf` aus dem App-Paket, nur lesbar, in einem eigenen Fenster. Quelle
/// ist `Scripts/hilfe/Kurzanleitung.html` (`Scripts/kurzanleitung.sh`): RTF lädt ohne WebKit, nicht spürbar auf dem
/// Hauptthread (Richtlinien 3.7).
final class QuickStartWindowController: NSWindowController {
    init() {
        let scroll: NSScrollView = NSTextView.scrollableTextView()
        if let text = scroll.documentView as? NSTextView {
            text.isEditable = false
            text.textContainerInset = NSSize(width: 20, height: 16)
            text.textStorage?.setAttributedString(Self.guide())
            text.setAccessibilityLabel("Kurzanleitung")
        }
        let window: NSWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 680),
                                        styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                        backing: .buffered, defer: false)
        window.title = "Kurzanleitung"
        window.contentView = scroll
        window.contentMinSize = NSSize(width: 420, height: 320)
        window.isRestorable = false
        super.init(window: window)
        if !window.setFrameUsingName("Kurzanleitung") { window.center() }
        window.setFrameAutosaveName("Kurzanleitung")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht benutzt") }

    /// Feste Farben aus der Umwandlung durch die Textfarbe des Systems ersetzt (Hell/Dunkel); Links behalten ihre Farbe.
    /// „-apple-system“ aus dem HTML speichert RTF als Helvetica Neue: wieder die Systemschrift in Größe und Stärke.
    /// Die Aufzählungszeichen zeichnet TextKit 2 aus den `NSTextList`s der Absätze.
    static func guide(bundle: Bundle = .main) -> NSAttributedString {
        guard let url = bundle.url(forResource: "Kurzanleitung", withExtension: "rtf"),
              let text = try? NSMutableAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                        documentAttributes: nil) else {
            return NSAttributedString(string: "Die Kurzanleitung fehlt im App-Paket.",
                                      attributes: [.foregroundColor: NSColor.textColor])
        }
        let whole: NSRange = NSRange(location: 0, length: text.length)
        text.removeAttribute(.backgroundColor, range: whole)
        text.enumerateAttribute(.link, in: whole) { value, range, _ in
            if value == nil { text.addAttribute(.foregroundColor, value: NSColor.textColor, range: range) }
        }
        text.enumerateAttribute(.font, in: whole) { value, range, _ in
            guard let font = value as? NSFont, font.familyName == "Helvetica Neue" else { return }
            let isBold: Bool = font.fontDescriptor.symbolicTraits.contains(.bold)
            text.addAttribute(.font, value: NSFont.systemFont(ofSize: font.pointSize, weight: isBold ? .bold : .regular), range: range)
        }
        return text
    }
}
