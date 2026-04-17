import Cocoa

class MainViewController: NSViewController {

    // MARK: - Children
    private lazy var clipboardVC    = ClipboardViewController()
    private lazy var sonosVC        = SonosViewController()
    private lazy var colorPickerVC  = ColorPickerViewController()
    private lazy var settingsVC     = SettingsViewController()

    // MARK: - Tab bar
    private var vibrancyBG:    NSVisualEffectView!
    private var tabControl:    NSSegmentedControl!
    private var tabDivider:    NSBox!
    private var gearBtn:       NSButton!

    // Clipboard search bar
    private var searchContainer: NSView!
    private var searchIcon:      NSImageView!
    private var inputField:      NSTextField!
    private var searchDivider:   NSBox!

    private var showingSettings = false

    private var keyMonitor: Any?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildBackground()
        buildTabBar()
        buildSearchBar()
        embedChildren()
        switchTab(to: 0)
        installKeyMonitor()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.modifierFlags.contains(.command) else { return event }
            switch event.charactersIgnoringModifiers {
            case "1": self.switchTab(to: 0); return nil
            case "2": self.switchTab(to: 1); return nil
            case "3": self.switchTab(to: 2); return nil
            default:  return event
            }
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        applyLayout()
    }

    // MARK: - Constants
    private let tabH:  CGFloat = 44
    private let barH:  CGFloat = 50
    private let divH:  CGFloat = 1
    private let hPad:  CGFloat = 16

    // MARK: - Build

    private func buildBackground() {
        vibrancyBG = NSVisualEffectView()
        vibrancyBG.material = .sidebar
        vibrancyBG.blendingMode = .behindWindow
        vibrancyBG.state = .active
        vibrancyBG.autoresizingMask = [.width, .height]
        view.addSubview(vibrancyBG, positioned: .below, relativeTo: nil)
    }

    private func buildTabBar() {
        tabControl = NSSegmentedControl(labels: ["Clipboard", "Sonos", "Color"],
                                        trackingMode: .selectOne,
                                        target: self,
                                        action: #selector(tabChanged))
        tabControl.selectedSegment = 0
        tabControl.segmentStyle    = .automatic
        tabControl.font            = NSFont.systemFont(ofSize: 12, weight: .medium)
        view.addSubview(tabControl)

        // Gear / settings button
        gearBtn = NSButton()
        gearBtn.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        gearBtn.imageScaling = .scaleProportionallyDown
        gearBtn.bezelStyle = .inline
        gearBtn.isBordered = false
        gearBtn.contentTintColor = .secondaryLabelColor
        gearBtn.action = #selector(toggleSettings)
        gearBtn.target = self
        view.addSubview(gearBtn)

        tabDivider = NSBox(); tabDivider.boxType = .separator
        view.addSubview(tabDivider)
    }

    private func buildSearchBar() {
        searchContainer = NSView()
        searchContainer.wantsLayer = true
        searchContainer.layer?.cornerRadius = 10
        searchContainer.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
        view.addSubview(searchContainer)

        searchIcon = NSImageView()
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        searchIcon.contentTintColor = .tertiaryLabelColor
        searchIcon.imageScaling = .scaleProportionallyDown
        searchContainer.addSubview(searchIcon)

        inputField = NSTextField()
        inputField.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        inputField.placeholderString = "Search clipboard…"
        inputField.isBordered = false
        inputField.drawsBackground = false
        inputField.focusRingType = .none
        inputField.delegate = self
        searchContainer.addSubview(inputField)

        searchDivider = NSBox(); searchDivider.boxType = .separator
        view.addSubview(searchDivider)
    }

    private func embedChildren() {
        for vc in [clipboardVC, sonosVC, colorPickerVC, settingsVC] as [NSViewController] {
            addChild(vc)
            view.addSubview(vc.view)
        }
    }

    // MARK: - Layout

    private func applyLayout() {
        let w = view.bounds.width
        let h = view.bounds.height

        vibrancyBG.frame = view.bounds

        // — Tab bar row —
        let gearSize: CGFloat = 20
        let gearX = w - hPad - gearSize
        gearBtn.frame = NSRect(x: gearX, y: h - tabH + (tabH - gearSize) / 2,
                               width: gearSize, height: gearSize)
        let tabW = gearX - hPad * 2
        tabControl.frame = NSRect(x: hPad, y: h - tabH + (tabH - 24) / 2,
                                  width: tabW, height: 24)
        tabDivider.frame = NSRect(x: 0, y: h - tabH - divH, width: w, height: divH)

        let contentTop = h - tabH - divH

        // Search bar — visible only on Clipboard tab
        let onClipboard = tabControl.selectedSegment == 0
        let containerH: CGFloat = 36
        let containerY = contentTop - (barH + containerH) / 2
        let showSearch = onClipboard && !showingSettings
        searchContainer.isHidden = !showSearch
        searchDivider.isHidden   = !showSearch
        searchContainer.frame = NSRect(x: hPad, y: containerY,
                                       width: w - hPad * 2, height: containerH)
        let iconSize: CGFloat = 14
        searchIcon.frame = NSRect(x: 10, y: (containerH - iconSize) / 2,
                                  width: iconSize, height: iconSize)
        inputField.frame = NSRect(x: 30, y: (containerH - 20) / 2,
                                  width: searchContainer.bounds.width - 36, height: 20)
        searchDivider.frame = NSRect(x: 0, y: containerY - 8 - divH, width: w, height: divH)

        let contentBottom: CGFloat
        if showingSettings {
            contentBottom = contentTop
        } else if showSearch {
            contentBottom = containerY - 8 - divH
        } else {
            contentBottom = contentTop
        }
        clipboardVC.view.frame   = NSRect(x: 0, y: 0, width: w, height: contentBottom)
        sonosVC.view.frame       = NSRect(x: 0, y: 0, width: w, height: contentBottom)
        colorPickerVC.view.frame = NSRect(x: 0, y: 0, width: w, height: contentBottom)
        settingsVC.view.frame    = NSRect(x: 0, y: 0, width: w, height: contentTop)
    }

    // MARK: - Tab Switching

    @objc private func tabChanged() {
        switchTab(to: tabControl.selectedSegment)
    }

    @objc private func toggleSettings() {
        showingSettings.toggle()
        gearBtn.contentTintColor = showingSettings ? .controlAccentColor : .secondaryLabelColor
        updateVisibility()
        view.needsLayout = true
        applyLayout()
    }

    private func switchTab(to idx: Int) {
        tabControl.selectedSegment = idx
        showingSettings = false
        gearBtn.contentTintColor = .secondaryLabelColor
        updateVisibility()
        view.needsLayout = true
        applyLayout()
    }

    private func updateVisibility() {
        let idx = tabControl.selectedSegment
        clipboardVC.view.isHidden   = showingSettings || idx != 0
        sonosVC.view.isHidden       = showingSettings || idx != 1
        colorPickerVC.view.isHidden = showingSettings || idx != 2
        settingsVC.view.isHidden    = !showingSettings
    }
}

// MARK: - NSTextFieldDelegate

extension MainViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        clipboardVC.applyFilter(inputField.stringValue)
    }
    func control(_ control: NSControl, textView: NSTextView,
                 doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.cancelOperation(_:)) {
            inputField.stringValue = ""
            clipboardVC.applyFilter("")
            return true
        }
        return false
    }
}
