import AppKit

// Ohne Storyboard: Delegate selbst setzen (top-level Code läuft auf dem MainActor).
let application: NSApplication = NSApplication.shared
let appDelegate: AppDelegate = AppDelegate()
application.delegate = appDelegate
application.run()
