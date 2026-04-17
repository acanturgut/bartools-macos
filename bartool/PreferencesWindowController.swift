import Cocoa

class PreferencesWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.center()
        self.init(window: window)
        window.contentViewController = PreferencesViewController()
    }

    func showAndFocus() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

class PreferencesViewController: NSViewController {

    private var menuBarToggle: NSButton!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 160))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCurrentValues()
    }

    private func setupUI() {
        // Title
        let title = NSTextField(labelWithString: "Preferences")
        title.font = NSFont.boldSystemFont(ofSize: 15)
        title.frame = NSRect(x: 20, y: 120, width: 340, height: 22)
        view.addSubview(title)

        let sep = NSBox(frame: NSRect(x: 20, y: 110, width: 340, height: 1))
        sep.boxType = .separator
        view.addSubview(sep)

        // Menu bar toggle
        menuBarToggle = NSButton(checkboxWithTitle: "Show icon in menu bar", target: self, action: #selector(menuBarToggleChanged))
        menuBarToggle.frame = NSRect(x: 24, y: 76, width: 320, height: 22)
        view.addSubview(menuBarToggle)

        let menuBarNote = NSTextField(labelWithString: "Adds a ⚙ Tools icon to the menu bar for quick popover access.")
        menuBarNote.font = NSFont.systemFont(ofSize: 11)
        menuBarNote.textColor = .secondaryLabelColor
        menuBarNote.frame = NSRect(x: 44, y: 56, width: 310, height: 18)
        view.addSubview(menuBarNote)

        let sep2 = NSBox(frame: NSRect(x: 20, y: 44, width: 340, height: 1))
        sep2.boxType = .separator
        view.addSubview(sep2)

        // Done button
        let doneBtn = NSButton(frame: NSRect(x: 280, y: 10, width: 80, height: 28))
        doneBtn.title = "Done"
        doneBtn.bezelStyle = .rounded
        doneBtn.keyEquivalent = "\r"
        doneBtn.action = #selector(closeWindow)
        doneBtn.target = self
        view.addSubview(doneBtn)
    }

    private func loadCurrentValues() {
        menuBarToggle.state = Preferences.showMenuBarIcon ? .on : .off
    }

    @objc private func menuBarToggleChanged() {
        Preferences.showMenuBarIcon = menuBarToggle.state == .on
        NotificationCenter.default.post(name: .menuBarIconPreferenceChanged, object: nil)
    }

    @objc private func closeWindow() {
        view.window?.close()
    }
}

// MARK: - Preferences Storage

enum Preferences {
    static var showMenuBarIcon: Bool {
        get { UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showMenuBarIcon") }
    }

    static var openWindowOnLaunch: Bool {
        get { UserDefaults.standard.object(forKey: "openWindowOnLaunch") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "openWindowOnLaunch") }
    }
}

extension Notification.Name {
    static let menuBarIconPreferenceChanged = Notification.Name("menuBarIconPreferenceChanged")
}
