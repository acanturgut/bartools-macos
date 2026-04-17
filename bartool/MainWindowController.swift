import Cocoa

class MainWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "bartool"
        window.minSize = NSSize(width: 460, height: 520)

        // Remove stale autosave frame — it may have been saved off-screen
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame MainWindow")
        window.setFrameAutosaveName("MainWindow")
        window.center()

        self.init(window: window)
        window.contentViewController = MainViewController()
    }

    func showAndFocus() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        // Force the window to a visible position on the main screen
        if let screen = NSScreen.main, let w = window {
            let x = (screen.visibleFrame.width - w.frame.width) / 2 + screen.visibleFrame.origin.x
            let y = (screen.visibleFrame.height - w.frame.height) / 2 + screen.visibleFrame.origin.y
            w.setFrameOrigin(NSPoint(x: x, y: y))
        }
        window?.makeKeyAndOrderFront(NSApp)
        window?.orderFrontRegardless()
    }
}
