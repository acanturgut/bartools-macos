import Cocoa

// MARK: - Speaker Column View

class SonosSpeakerView: NSView {

    private var nameLabel:    NSTextField!
    private var trackLabel:   NSTextField!
    private var artistLabel:  NSTextField!
    private var slider:       NSSlider!
    private var volLabel:     NSTextField!
    private var prevBtn:      NSButton!
    private var playPauseBtn: NSButton!
    private var nextBtn:      NSButton!

    private(set) var device: SonosDevice!
    private var isPlaying        = false
    private var isAdjustingVol   = false
    private var volDebounce:     Timer?
    var onVolumeChange: ((SonosDevice, Int) -> Void)?

    // MARK: - Build

    func configure(device: SonosDevice) {
        self.device = device
        if nameLabel == nil { build() }
        nameLabel.stringValue = device.displayName
    }

    private func build() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6).cgColor

        nameLabel = lbl("", size: 11, weight: .semibold)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)

        trackLabel = lbl("—", size: 11, weight: .medium)
        trackLabel.textColor = .labelColor
        trackLabel.alignment = .center
        trackLabel.lineBreakMode = .byTruncatingTail
        addSubview(trackLabel)

        artistLabel = lbl("", size: 10)
        artistLabel.textColor = .secondaryLabelColor
        artistLabel.alignment = .center
        artistLabel.lineBreakMode = .byTruncatingTail
        addSubview(artistLabel)

        // Vertical slider
        slider = NSSlider(value: 50, minValue: 0, maxValue: 100, target: self, action: #selector(sliderMoved))
        slider.sliderType   = .linear
        slider.isVertical   = true
        slider.isContinuous = true
        addSubview(slider)

        volLabel = lbl("50", size: 10)
        volLabel.textColor = .tertiaryLabelColor
        volLabel.alignment = .center
        addSubview(volLabel)

        prevBtn      = tinyBtn("backward.fill",  #selector(tapPrev))
        playPauseBtn = tinyBtn("play.fill",       #selector(tapPlayPause))
        nextBtn      = tinyBtn("forward.fill",    #selector(tapNext))
        addSubview(prevBtn); addSubview(playPauseBtn); addSubview(nextBtn)
    }

    override func layout() {
        super.layout()
        guard nameLabel != nil else { return }
        let w = bounds.width
        let h = bounds.height
        let pad: CGFloat = 8
        var y = h - pad

        // name
        nameLabel.frame = NSRect(x: pad, y: y - 16, width: w - pad * 2, height: 16); y -= 20

        // track + artist
        trackLabel.frame  = NSRect(x: pad, y: y - 14, width: w - pad * 2, height: 14); y -= 16
        artistLabel.frame = NSRect(x: pad, y: y - 12, width: w - pad * 2, height: 12); y -= 18

        // transport buttons
        let btnW: CGFloat = 22
        let gap:  CGFloat = 6
        let totalBtns = btnW * 3 + gap * 2
        let bx = (w - totalBtns) / 2
        prevBtn.frame      = NSRect(x: bx,                  y: y - btnW, width: btnW, height: btnW)
        playPauseBtn.frame = NSRect(x: bx + btnW + gap,     y: y - btnW, width: btnW, height: btnW)
        nextBtn.frame      = NSRect(x: bx + (btnW+gap) * 2, y: y - btnW, width: btnW, height: btnW)
        y -= btnW + 8

        // vertical slider takes remaining height
        let sliderH = y - pad - 20  // leave room for vol label at bottom
        let sliderW: CGFloat = 26
        slider.frame  = NSRect(x: (w - sliderW) / 2, y: pad + 20, width: sliderW, height: max(sliderH, 40))
        volLabel.frame = NSRect(x: pad, y: pad, width: w - pad * 2, height: 16)
    }

    // MARK: - Update

    func updatePlayback(state: String?, title: String?, artist: String?) {
        isPlaying = (state == "PLAYING")
        let sym = isPlaying ? "pause.fill" : "play.fill"
        playPauseBtn.image = NSImage(systemSymbolName: sym, accessibilityDescription: nil)
        trackLabel.stringValue  = title  ?? "—"
        artistLabel.stringValue = artist ?? ""
    }

    func updateVolume(_ vol: Int) {
        guard !isAdjustingVol else { return }
        slider.doubleValue    = Double(vol)
        volLabel.stringValue  = "\(vol)"
    }

    // MARK: - Actions

    @objc private func sliderMoved() {
        let vol = Int(slider.doubleValue)
        volLabel.stringValue = "\(vol)"
        isAdjustingVol = true
        volDebounce?.invalidate()
        volDebounce = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.onVolumeChange?(self.device, vol)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.isAdjustingVol = false }
        }
        RunLoop.main.add(volDebounce!, forMode: .common)
    }

    @objc private func tapPlayPause() {
        let mgr = SonosManager.shared
        if isPlaying {
            mgr.pause(device: device) { [weak self] _ in self?.refreshState() }
        } else {
            mgr.play(device: device) { [weak self] _ in self?.refreshState() }
        }
    }
    @objc private func tapPrev() {
        SonosManager.shared.previous(device: device) { [weak self] _ in self?.refreshState() }
    }
    @objc private func tapNext() {
        SonosManager.shared.next(device: device) { [weak self] _ in self?.refreshState() }
    }

    private func refreshState() {
        SonosManager.shared.getTransportState(device: device) { [weak self] s in
            self?.updatePlayback(state: s, title: self?.trackLabel.stringValue,
                                 artist: self?.artistLabel.stringValue)
        }
    }

    // MARK: - Helpers

    private func lbl(_ s: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSTextField {
        let f = NSTextField(labelWithString: s)
        f.font = NSFont.systemFont(ofSize: size, weight: weight)
        f.isEditable = false
        return f
    }
    private func tinyBtn(_ sym: String, _ sel: Selector) -> NSButton {
        let b = NSButton()
        b.image = NSImage(systemSymbolName: sym, accessibilityDescription: nil)
        b.imageScaling = .scaleProportionallyDown
        b.bezelStyle = .inline; b.isBordered = false
        b.contentTintColor = .labelColor
        b.action = sel; b.target = self
        return b
    }
}

// MARK: - Main View Controller

class SonosViewController: NSViewController {

    private enum State { case discovering, noDevices, player }
    private var state: State = .discovering { didSet { applyState() } }

    private var discoveryView:  NSView!
    private var discoveryLabel: NSTextField!
    private var retryBtn:       NSButton!
    private var spinnerTimer:   Timer?

    private var playerView:     NSView!
    private var speakerViews:   [SonosSpeakerView] = []
    private var pollTimer:      Timer?

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildDiscoveryView()
        buildPlayerView()
        startDiscovery()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        discoveryView.frame = view.bounds
        playerView.frame    = view.bounds

        let dw = discoveryView.bounds.width
        let dh = discoveryView.bounds.height
        discoveryLabel.frame = NSRect(x: 16, y: dh / 2,     width: dw - 32, height: 20)
        retryBtn.frame       = NSRect(x: (dw - 80) / 2, y: dh / 2 - 34, width: 80, height: 26)

        layoutSpeakers()
    }

    // MARK: - Discovery

    private func buildDiscoveryView() {
        discoveryView = NSView()
        view.addSubview(discoveryView)

        discoveryLabel = NSTextField(labelWithString: "")
        discoveryLabel.font = NSFont.systemFont(ofSize: 13)
        discoveryLabel.textColor = .secondaryLabelColor
        discoveryLabel.alignment = .center
        discoveryView.addSubview(discoveryLabel)

        retryBtn = NSButton()
        retryBtn.title = "Retry"
        retryBtn.bezelStyle = .rounded
        retryBtn.isHidden = true
        retryBtn.action = #selector(retry); retryBtn.target = self
        discoveryView.addSubview(retryBtn)
    }

    private func buildPlayerView() {
        playerView = NSView()
        playerView.isHidden = true
        view.addSubview(playerView)
    }

    private func startDiscovery() {
        state = .discovering
        discoveryLabel.stringValue = "Discovering speakers\u{2026}"
        retryBtn.isHidden = true
        startSpinner()

        SonosManager.shared.onDevicesChanged = { [weak self] in
            self?.devicesUpdated()
        }
        SonosManager.shared.startDiscovery()

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard self?.state == .discovering else { return }
            if SonosManager.shared.devices.isEmpty { self?.state = .noDevices }
        }
    }

    private func startSpinner() {
        var dots = 0
        spinnerTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            dots = (dots % 3) + 1
            self?.discoveryLabel.stringValue = "Discovering speakers" + String(repeating: ".", count: dots)
        }
        RunLoop.main.add(spinnerTimer!, forMode: .common)
    }

    private func devicesUpdated() {
        let devices = SonosManager.shared.devices
        guard !devices.isEmpty else { return }
        spinnerTimer?.invalidate()
        rebuildSpeakerViews(devices: devices)
        state = .player
        startPolling()
    }

    @objc private func retry() {
        stopPolling()
        startDiscovery()
    }

    // MARK: - Speaker views

    private func rebuildSpeakerViews(devices: [SonosDevice]) {
        speakerViews.forEach { $0.removeFromSuperview() }
        speakerViews = devices.map { device in
            let sv = SonosSpeakerView()
            sv.configure(device: device)
            sv.onVolumeChange = { dev, vol in
                SonosManager.shared.setVolume(device: dev, volume: vol) { _ in }
            }
            playerView.addSubview(sv)
            return sv
        }
        layoutSpeakers()
    }

    private func layoutSpeakers() {
        guard !speakerViews.isEmpty else { return }
        let w      = playerView.bounds.width
        let h      = playerView.bounds.height
        let n      = CGFloat(speakerViews.count)
        let pad:   CGFloat = 10
        let gap:   CGFloat = 8
        let colW   = (w - pad * 2 - gap * (n - 1)) / n

        for (i, sv) in speakerViews.enumerated() {
            let x = pad + CGFloat(i) * (colW + gap)
            sv.frame = NSRect(x: x, y: pad, width: colW, height: h - pad * 2)
        }
    }

    // MARK: - Polling

    private func startPolling() {
        stopPolling()
        refreshAll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
    }

    private func stopPolling() { pollTimer?.invalidate(); pollTimer = nil }

    private func refreshAll() {
        let mgr = SonosManager.shared
        for sv in speakerViews {
            let dev = sv.device!
            mgr.getTransportState(device: dev) { state in
                mgr.getPositionInfo(device: dev) { title, artist, _ in
                    sv.updatePlayback(state: state, title: title, artist: artist)
                }
            }
            mgr.getVolume(device: dev) { vol in
                if let v = vol { sv.updateVolume(v) }
            }
        }
    }

    // MARK: - State

    private func applyState() {
        switch state {
        case .discovering:
            discoveryView.isHidden = false; playerView.isHidden = true
            discoveryLabel.stringValue = "Discovering speakers\u{2026}"; retryBtn.isHidden = true
        case .noDevices:
            spinnerTimer?.invalidate()
            discoveryView.isHidden = false; playerView.isHidden = true
            discoveryLabel.stringValue = "No Sonos speakers found."; retryBtn.isHidden = false
        case .player:
            discoveryView.isHidden = true; playerView.isHidden = false
        }
        view.needsLayout = true; view.layoutSubtreeIfNeeded()
    }
}
