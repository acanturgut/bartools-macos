import Cocoa

class ColorPickerViewController: NSViewController {

    // MARK: - UI
    private var previewBox:      NSView!
    private var hexField:        NSTextField!
    private var rField:          NSTextField!
    private var gField:          NSTextField!
    private var bField:          NSTextField!
    private var copyHexBtn:      NSButton!
    private var copyRGBBtn:      NSButton!
    private var pickScreenBtn:   NSButton!
    private var swatchViews:     [NSView] = []
    private var statusLabel:     NSTextField!

    // MARK: - State
    private var currentColor: NSColor = .systemBlue { didSet { syncFields() } }

    private let swatchColors: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemTeal, .systemBlue, .systemIndigo, .systemPurple,
        .systemPink, .white, NSColor(white: 0.5, alpha: 1), .black
    ]

    // MARK: - Lifecycle

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        syncFields()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutUI()
    }

    // MARK: - Build UI

    private func buildUI() {
        // Preview strip
        previewBox = NSView()
        previewBox.wantsLayer = true
        previewBox.layer?.cornerRadius = 10
        view.addSubview(previewBox)

        // "Pick from Screen" — uses NSColorSampler eyedropper
        pickScreenBtn = NSButton()
        pickScreenBtn.title = "  Pick from Screen"
        pickScreenBtn.image = NSImage(systemSymbolName: "eyedropper.halffull", accessibilityDescription: nil)
        pickScreenBtn.imagePosition = .imageLeading
        pickScreenBtn.bezelStyle = .rounded
        pickScreenBtn.contentTintColor = .controlAccentColor
        pickScreenBtn.target = self
        pickScreenBtn.action = #selector(pickFromScreen)
        view.addSubview(pickScreenBtn)

        // Open system color panel
        let panelBtn = NSButton()
        panelBtn.title = "  Color Panel…"
        panelBtn.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: nil)
        panelBtn.imagePosition = .imageLeading
        panelBtn.bezelStyle = .rounded
        panelBtn.target = self; panelBtn.action = #selector(openColorPanel)
        panelBtn.tag = 901
        view.addSubview(panelBtn)

        // HEX row
        let hexLbl = sectionLabel("HEX")
        view.addSubview(hexLbl); hexLbl.tag = 801

        hexField = monoField(placeholder: "#RRGGBB")
        hexField.delegate = self
        view.addSubview(hexField)

        copyHexBtn = actionBtn("Copy HEX", #selector(copyHex))
        view.addSubview(copyHexBtn)

        // RGB row
        let rgbLbl = sectionLabel("RGB")
        view.addSubview(rgbLbl); rgbLbl.tag = 802

        rField = channelField(placeholder: "R"); rField.delegate = self
        gField = channelField(placeholder: "G"); gField.delegate = self
        bField = channelField(placeholder: "B"); bField.delegate = self
        [rField, gField, bField].forEach { view.addSubview($0) }

        copyRGBBtn = actionBtn("Copy RGB", #selector(copyRGB))
        view.addSubview(copyRGBBtn)

        // Swatches
        let swLbl = sectionLabel("Swatches")
        swLbl.tag = 803
        view.addSubview(swLbl)

        for color in swatchColors {
            let sw = makeSwatchView(color: color)
            view.addSubview(sw)
            swatchViews.append(sw)
        }

        // Status
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 10)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        view.addSubview(statusLabel)
    }

    // MARK: - Layout

    private func layoutUI() {
        let w = view.bounds.width
        let h = view.bounds.height
        let pad: CGFloat = 16
        guard w > 0, h > 0 else { return }

        // Preview strip at top
        previewBox.frame = NSRect(x: pad, y: h - 56, width: w - pad * 2, height: 40)
        previewBox.layer?.backgroundColor = currentColor.cgColor

        // Two buttons side by side
        let btnW = (w - pad * 2 - 8) / 2
        pickScreenBtn.frame = NSRect(x: pad,          y: h - 100, width: btnW, height: 28)
        view.viewWithTag(901)?.frame = NSRect(x: pad + btnW + 8, y: h - 100, width: btnW, height: 28)

        // HEX row
        let secY1 = h - 138
        view.viewWithTag(801)?.frame = NSRect(x: pad, y: secY1 + 2, width: 30, height: 16)
        hexField.frame  = NSRect(x: pad + 34,  y: secY1, width: w - pad * 2 - 34 - 88 - 8, height: 24)
        copyHexBtn.frame = NSRect(x: w - pad - 88, y: secY1, width: 88, height: 24)

        // RGB row
        let secY2 = h - 174
        view.viewWithTag(802)?.frame = NSRect(x: pad, y: secY2 + 2, width: 30, height: 16)
        let chW = (w - pad * 2 - 34 - 88 - 8 - 8) / 3
        rField.frame = NSRect(x: pad + 34,              y: secY2, width: chW, height: 24)
        gField.frame = NSRect(x: pad + 34 + chW + 4,   y: secY2, width: chW, height: 24)
        bField.frame = NSRect(x: pad + 34 + chW*2 + 8, y: secY2, width: chW, height: 24)
        copyRGBBtn.frame = NSRect(x: w - pad - 88, y: secY2, width: 88, height: 24)

        // Swatches
        let secY3 = h - 202
        view.viewWithTag(803)?.frame = NSRect(x: pad, y: secY3, width: 60, height: 14)
        let cols = swatchColors.count
        let swSize: CGFloat = min(28, (w - pad * 2 - CGFloat(cols - 1) * 5) / CGFloat(cols))
        let totalSwW = CGFloat(cols) * swSize + CGFloat(cols - 1) * 5
        var sx = (w - totalSwW) / 2
        let sy = h - 238
        for sw in swatchViews {
            sw.frame = NSRect(x: sx, y: sy, width: swSize, height: swSize)
            sx += swSize + 5
        }

        // Status
        statusLabel.frame = NSRect(x: pad, y: sy - 22, width: w - pad * 2, height: 14)
    }

    // MARK: - Private helpers

    private func sectionLabel(_ s: String) -> NSTextField {
        let f = NSTextField(labelWithString: s)
        f.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        f.textColor = .tertiaryLabelColor
        return f
    }

    private func monoField(placeholder: String) -> NSTextField {
        let f = NSTextField()
        f.placeholderString = placeholder
        f.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        f.bezelStyle = .roundedBezel; f.isBordered = true
        return f
    }

    private func channelField(placeholder: String) -> NSTextField {
        let f = monoField(placeholder: placeholder)
        f.alignment = .center
        return f
    }

    private func actionBtn(_ title: String, _ sel: Selector) -> NSButton {
        let b = NSButton(); b.title = title; b.bezelStyle = .rounded
        b.font = NSFont.systemFont(ofSize: 11); b.target = self; b.action = sel
        return b
    }

    private func makeSwatchView(color: NSColor) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 6
        v.layer?.borderWidth = 1
        v.layer?.borderColor = NSColor.separatorColor.cgColor
        v.layer?.backgroundColor = color.cgColor
        let click = NSClickGestureRecognizer(target: self, action: #selector(swatchTapped(_:)))
        v.addGestureRecognizer(click)
        return v
    }

    private func syncFields() {
        guard isViewLoaded else { return }
        previewBox?.layer?.backgroundColor = currentColor.cgColor
        if let rgb = currentColor.usingColorSpace(.sRGB) {
            let r = Int((rgb.redComponent   * 255).rounded())
            let g = Int((rgb.greenComponent * 255).rounded())
            let b = Int((rgb.blueComponent  * 255).rounded())
            hexField?.stringValue = String(format: "#%02X%02X%02X", r, g, b)
            rField?.stringValue   = "\(r)"
            gField?.stringValue   = "\(g)"
            bField?.stringValue   = "\(b)"
        }
    }

    // MARK: - Actions

    @objc private func pickFromScreen() {
        let sampler = NSColorSampler()
        statusLabel.stringValue = "Click anywhere on screen to pick a color…"
        sampler.show { [weak self] color in
            guard let self, let color else {
                self?.statusLabel.stringValue = "Pick cancelled."
                return
            }
            self.currentColor = color
            self.statusLabel.stringValue = "Color picked!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.statusLabel.stringValue = ""
            }
        }
    }

    @objc private func openColorPanel() {
        NSColorPanel.shared.showsAlpha = false
        NSColorPanel.shared.color = currentColor
        NSColorPanel.shared.makeKeyAndOrderFront(nil)
        NotificationCenter.default.removeObserver(self, name: NSColorPanel.colorDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(panelColorChanged),
            name: NSColorPanel.colorDidChangeNotification, object: NSColorPanel.shared)
    }

    @objc private func panelColorChanged() {
        currentColor = NSColorPanel.shared.color
    }

    @objc private func swatchTapped(_ rec: NSClickGestureRecognizer) {
        guard let idx = swatchViews.firstIndex(of: rec.view!) else { return }
        currentColor = swatchColors[idx]
    }

    @objc private func copyHex() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hexField.stringValue, forType: .string)
        flashStatus("Copied \(hexField.stringValue)")
    }

    @objc private func copyRGB() {
        let t = "rgb(\(rField.stringValue), \(gField.stringValue), \(bField.stringValue))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(t, forType: .string)
        flashStatus("Copied \(t)")
    }

    private func flashStatus(_ msg: String) {
        statusLabel.stringValue = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.statusLabel.stringValue = ""
        }
    }
}

// MARK: - NSTextFieldDelegate

extension ColorPickerViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field == hexField {
            let raw = hexField.stringValue.trimmingCharacters(in: .whitespaces)
            let hex = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
            if let color = NSColor(hexString: hex) { currentColor = color }
        } else {
            let r = CGFloat((Int(rField.stringValue) ?? 0).clamped(to: 0...255)) / 255
            let g = CGFloat((Int(gField.stringValue) ?? 0).clamped(to: 0...255)) / 255
            let b = CGFloat((Int(bField.stringValue) ?? 0).clamped(to: 0...255)) / 255
            currentColor = NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        }
    }
}

// MARK: - Extensions

extension NSColor {
    convenience init?(hexString: String) {
        let s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count == 6 || s.count == 8 else { return nil }
        var v: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&v) else { return nil }
        if s.count == 6 {
            self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                      green:   CGFloat((v >>  8) & 0xFF) / 255,
                      blue:    CGFloat( v         & 0xFF) / 255, alpha: 1)
        } else {
            self.init(srgbRed: CGFloat((v >> 24) & 0xFF) / 255,
                      green:   CGFloat((v >> 16) & 0xFF) / 255,
                      blue:    CGFloat((v >>  8) & 0xFF) / 255,
                      alpha:   CGFloat( v         & 0xFF) / 255)
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
