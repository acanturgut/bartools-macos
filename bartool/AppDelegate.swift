import SwiftUI
import Carbon.HIToolbox

// MARK: - Global Ctrl+Space hotkey handler (C-callable)

func clipboardHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ theEvent: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        // Toggle the menu bar extra window
        if let win = NSApp.windows.first(where: { $0.canBecomeKey }) {
            if win.isVisible && win.isKeyWindow {
                win.orderOut(nil)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                win.makeKeyAndOrderFront(nil)
            }
        }
    }
    return noErr
}

private func makeFourCharCode(_ s: String) -> OSType {
    var result: OSType = 0
    for scalar in s.unicodeScalars.prefix(4) {
        result = (result << 8) | OSType(scalar.value)
    }
    return result
}

// MARK: - App Entry Point (SwiftUI – required for macOS 26)

@main
struct bartool: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra("bartool", systemImage: "list.clipboard") {
            bartoolContent()
                .frame(width: 440, height: 540)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Bridge to AppKit

struct bartoolContent: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> MainViewController { MainViewController() }
    func updateNSViewController(_ nsViewController: MainViewController, context: Context) {}
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerRef: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = ClipboardManager.shared
        registerGlobalHotKey()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidOpen(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        DispatchQueue.main.async { self.hideChrome() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // URL scheme handler (reserved for future use)
    }

    @objc private func windowDidOpen(_ note: Notification) {
        hideChrome()
    }

    private func hideChrome() {
        for win in NSApp.windows {
            win.standardWindowButton(.closeButton)?.isHidden = true
            win.standardWindowButton(.miniaturizeButton)?.isHidden = true
            win.standardWindowButton(.zoomButton)?.isHidden = true
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.styleMask.insert(.fullSizeContentView)
        }
    }

    private func registerGlobalHotKey() {
        var hkID = EventHotKeyID()
        hkID.signature = makeFourCharCode("CBKP")
        hkID.id = 1

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            clipboardHotKeyHandler,
            1, &eventType, nil,
            &hotKeyHandlerRef
        )

        // Ctrl+Option+Space
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey),
            hkID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
