import Cocoa

// Flipped so subview origins go top-to-bottom
private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

class SettingsViewController: NSViewController {

    private var scrollView:    NSScrollView!
    private var contentView:   FlippedView!

    // General
    private var launchCheck:   NSButton!

    // Clipboard
    private var limitField:    NSTextField!
    private var limitStepper:  NSStepper!

    // Sonos
    private var pollField:     NSTextField!
    private var pollStepper:   NSStepper!
    private var discField:     NSTextField!
    private var discStepper:   NSStepper!

    // Layout cursor (flipped: top → down)
    private var cursor: CGFloat = 0
    private let rowH:   CGFloat = 44
    private let secGap: CGFloat = 20
    private let hPad:   CGFloat = 16

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        loadValues()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let w = view.bounds.width
        scrollView.frame = view.bounds
        contentView.frame = NSRect(x: 0, y: 0, width: w, height: max(cursor + 16, view.bounds.height))
    }

    // MARK: - Build

    private func buildUI() {
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        view.addSubview(scrollView)

        contentView = FlippedView()
        contentView.wantsLayer = true
        scrollView.documentView = contentView

        cursor = 20

        // ── General ──
        addSectionHeader("General")
        launchCheck = addCheckboxRow(title: "Launch at startup", action: #selector(launchToggled))

        cursor += secGap

        // ── Clipboard ──
        addSectionHeader("Clipboard")
        (limitField, limitStepper) = addStepperRow(
            title: "History limit",
            unit: "items",
            min: 10, max: 1000, step: 10,
            action: #selector(limitChanged)
        )

        cursor += secGap

        // ── Sonos ──
        addSectionHeader("Sonos")
        (pollField, pollStepper) = addStepperRow(
            title: "Poll interval",
            unit: "sec",
            min: 1, max: 30, step: 1,
            action: #selector(pollChanged)
        )
        (discField, discStepper) = addStepperRow(
            title: "Discovery timeout",
            unit: "sec",
            min: 3, max: 60, step: 1,
            action: #selector(discChanged)
        )

        cursor += 24  // bottom padding
    }

    // MARK: - Layout helpers

    private func addSectionHeader(_ title: String) {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        label.frame = NSRect(x: hPad, y: cursor, width: 300, height: 16)
        contentView.addSubview(label)
        cursor += 22

        // Thin separator line
        let line = NSBox()
        line.boxType = .separator
        line.frame = NSRect(x: hPad, y: cursor, width: 9999, height: 1)
        contentView.addSubview(line)
        cursor += 8
    }

    @discardableResult
    private func addCheckboxRow(title: String, action: Selector) -> NSButton {
        let bg = rowBackground(at: cursor)
        contentView.addSubview(bg)

        let label = rowLabel(title)
        label.frame = NSRect(x: hPad + 8, y: cursor + (rowH - 16) / 2, width: 220, height: 16)
        contentView.addSubview(label)

        let check = NSButton(checkboxWithTitle: "", target: self, action: action)
        check.frame = NSRect(x: 9999, y: cursor + (rowH - 18) / 2, width: 18, height: 18)  // x set in layout
        check.tag = 900
        contentView.addSubview(check)

        cursor += rowH
        return check
    }

    @discardableResult
    private func addStepperRow(title: String, unit: String,
                                min: Double, max: Double, step: Double,
                                action: Selector) -> (NSTextField, NSStepper) {
        let bg = rowBackground(at: cursor)
        contentView.addSubview(bg)

        let label = rowLabel(title)
        label.frame = NSRect(x: hPad + 8, y: cursor + (rowH - 16) / 2, width: 200, height: 16)
        contentView.addSubview(label)

        let valField = NSTextField()
        valField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        valField.isBordered = false
        valField.drawsBackground = false
        valField.isEditable = false
        valField.alignment = .right
        valField.textColor = .secondaryLabelColor
        valField.frame = NSRect(x: 9000, y: cursor + (rowH - 18) / 2, width: 40, height: 18)
        contentView.addSubview(valField)

        let unitLbl = NSTextField(labelWithString: unit)
        unitLbl.font = NSFont.systemFont(ofSize: 11)
        unitLbl.textColor = .tertiaryLabelColor
        unitLbl.frame = NSRect(x: 9100, y: cursor + (rowH - 16) / 2, width: 36, height: 16)
        contentView.addSubview(unitLbl)

        let stepper = NSStepper()
        stepper.minValue = min; stepper.maxValue = max; stepper.increment = step
        stepper.valueWraps = false
        stepper.action = action; stepper.target = self
        stepper.frame = NSRect(x: 9200, y: cursor + (rowH - 22) / 2, width: 22, height: 22)
        contentView.addSubview(stepper)

        cursor += rowH
        return (valField, stepper)
    }

    private func rowBackground(at y: CGFloat) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 8
        v.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.06).cgColor
        v.frame = NSRect(x: hPad, y: y, width: 9999, height: rowH - 4)
        return v
    }

    private func rowLabel(_ title: String) -> NSTextField {
        let f = NSTextField(labelWithString: title)
        f.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        f.textColor = .labelColor
        return f
    }

    // MARK: - Dynamic layout (x positions depend on width)

    override func viewDidAppear() {
        super.viewDidAppear()
        repositionRightSideControls()
    }

    private func repositionRightSideControls() {
        let w = contentView.bounds.width
        let rPad: CGFloat = hPad + 8

        // Resize all row backgrounds
        for v in contentView.subviews where v.layer?.cornerRadius == 8 {
            v.frame.size.width = w - hPad * 2
        }

        let stepperW: CGFloat = 22
        let valW:     CGFloat = 44
        let unitW:    CGFloat = 38
        let gapS:     CGFloat = 4

        // Launch checkbox
        if let c = contentView.viewWithTag(900) as? NSButton {
            c.frame.origin.x = w - rPad - 18
        }

        // Re-position stepper rows: [valField][unit][stepper] right-aligned
        let triplets: [(NSTextField, NSTextField, NSStepper)] = [
            // We match by pointer — walk subviews in order
        ]
        _ = triplets

        // Walk all steppers
        for sub in contentView.subviews {
            if let stepper = sub as? NSStepper {
                stepper.frame.origin.x = w - rPad - stepperW
            }
        }
        // val fields (secondary label, right of stepper)
        for sub in contentView.subviews {
            if let tf = sub as? NSTextField,
               tf.font == NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular) {
                // find corresponding stepper (same vertical center)
                let centerY = tf.frame.midY
                if let st = contentView.subviews.compactMap({ $0 as? NSStepper }).first(where: { abs($0.frame.midY - centerY) < 4 }) {
                    // unit label sits between valField and stepper
                    let stX = st.frame.origin.x
                    tf.frame.origin.x = stX - gapS - unitW - gapS - valW
                    // find unit label
                    for usub in contentView.subviews {
                        if let ul = usub as? NSTextField,
                           ul !== tf,
                           ul.textColor == NSColor.tertiaryLabelColor,
                           abs(ul.frame.midY - centerY) < 4 {
                            ul.frame.origin.x = stX - gapS - unitW
                        }
                    }
                }
            }
        }

        scrollView.frame = view.bounds
        let totalH = max(cursor + 16, view.bounds.height)
        contentView.frame = NSRect(x: 0, y: 0, width: w, height: totalH)
    }

    // MARK: - Load / Save

    private func loadValues() {
        let p = AppPreferences.shared
        launchCheck.state = p.launchAtLogin ? .on : .off

        limitStepper.doubleValue = Double(p.clipboardLimit)
        limitField.stringValue   = "\(p.clipboardLimit)"

        pollStepper.doubleValue = p.sonosPollInterval
        pollField.stringValue   = "\(Int(p.sonosPollInterval))"

        discStepper.doubleValue = p.sonosDiscoveryTimeout
        discField.stringValue   = "\(Int(p.sonosDiscoveryTimeout))"
    }

    // MARK: - Actions

    @objc private func launchToggled() {
        AppPreferences.shared.launchAtLogin = (launchCheck.state == .on)
        // Re-read actual state (SMAppService may reject)
        launchCheck.state = AppPreferences.shared.launchAtLogin ? .on : .off
    }

    @objc private func limitChanged() {
        let v = Int(limitStepper.doubleValue)
        AppPreferences.shared.clipboardLimit = v
        limitField.stringValue = "\(v)"
    }

    @objc private func pollChanged() {
        let v = pollStepper.doubleValue
        AppPreferences.shared.sonosPollInterval = v
        pollField.stringValue = "\(Int(v))"
    }

    @objc private func discChanged() {
        let v = discStepper.doubleValue
        AppPreferences.shared.sonosDiscoveryTimeout = v
        discField.stringValue = "\(Int(v))"
    }
}
