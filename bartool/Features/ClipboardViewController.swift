import Cocoa

class ClipboardViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var countLabel: NSTextField!
    private var emptyLabel: NSTextField!
    private var clearButton: NSButton!
    private(set) var filteredHistory: [ClipboardItem] = []
    private var currentFilter = ""

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        filteredHistory = ClipboardManager.shared.history
        buildUI()
        reloadData()

        ClipboardManager.shared.onHistoryChanged = { [weak self] in
            DispatchQueue.main.async { self?.reloadData() }
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutSubviews()
    }

    // MARK: - Build

    private func buildUI() {
        // Borderless scroll + table
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        view.addSubview(scrollView)

        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none   // we paint selection ourselves
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.doubleAction = #selector(copySelected)
        tableView.target = self

        let col = NSTableColumn(identifier: .init("col"))
        col.resizingMask = .autoresizingMask
        tableView.addTableColumn(col)

        scrollView.documentView = tableView
        tableView.sizeLastColumnToFit()

        // Empty state label
        emptyLabel = NSTextField(labelWithString: "No clipboard history yet.\nCopy something to get started.")
        emptyLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true
        (emptyLabel.cell as? NSTextFieldCell)?.wraps = true
        view.addSubview(emptyLabel)

        // Footer: count + clear
        countLabel = NSTextField(labelWithString: "")
        countLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = .tertiaryLabelColor
        view.addSubview(countLabel)

        clearButton = NSButton()
        clearButton.title = "Clear All"
        clearButton.bezelStyle = .inline
        clearButton.isBordered = false
        clearButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        clearButton.contentTintColor = .systemRed
        clearButton.action = #selector(clearHistory)
        clearButton.target = self
        view.addSubview(clearButton)
    }

    private func layoutSubviews() {
        let w = view.bounds.width
        let h = view.bounds.height
        let footerH: CGFloat = 36
        let hPad: CGFloat = 16

        scrollView.frame = NSRect(x: 0, y: footerH, width: w, height: max(0, h - footerH))
        tableView.frame  = NSRect(x: 0, y: 0, width: w, height: max(0, h - footerH))
        tableView.sizeLastColumnToFit()

        emptyLabel.frame = NSRect(x: hPad, y: footerH + (h - footerH) / 2 - 30,
                                   width: w - hPad * 2, height: 60)

        countLabel.frame  = NSRect(x: hPad, y: 0, width: 160, height: footerH)
        clearButton.frame = NSRect(x: w - 72 - hPad, y: 0, width: 72, height: footerH)
    }

    // MARK: - Data

    private func refreshFilteredHistory() {
        filteredHistory = currentFilter.isEmpty
            ? ClipboardManager.shared.history
            : ClipboardManager.shared.history.filter {
                $0.content.localizedCaseInsensitiveContains(currentFilter)
              }
    }

    private func reloadData() {
        refreshFilteredHistory()
        tableView.reloadData()
        let n = filteredHistory.count
        countLabel.stringValue = n == 0 ? "" : "\(n) item\(n == 1 ? "" : "s")"
        emptyLabel.isHidden = n > 0
        clearButton.isHidden = n == 0
    }

    // MARK: - Public API

    func applyFilter(_ query: String) {
        currentFilter = query
        guard isViewLoaded else { return }
        reloadData()
    }

    // MARK: - Actions

    @objc private func copySelected() {
        let row = tableView.selectedRow
        guard filteredHistory.indices.contains(row) else { return }
        ClipboardManager.shared.copyToClipboard(filteredHistory[row])
        if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? ClipboardCell {
            cell.flashCopied()
        }
    }

    @objc private func clearHistory() {
        ClipboardManager.shared.clearHistory()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { filteredHistory.count }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("ClipboardCell")
        let cell = (tableView.makeView(withIdentifier: id, owner: self) as? ClipboardCell) ?? ClipboardCell()
        cell.identifier = id
        cell.configure(with: filteredHistory[row], index: row, owner: self)
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        ClipboardRowView()
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 56 }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 { copySelected() } else { super.keyDown(with: event) }
    }
}

// MARK: - ClipboardCellDelegate

protocol ClipboardCellDelegate: AnyObject {
    func didRequestDelete(at index: Int)
}

extension ClipboardViewController: ClipboardCellDelegate {
    func didRequestDelete(at index: Int) {
        guard filteredHistory.indices.contains(index) else { return }
        let item = filteredHistory[index]
        if let real = ClipboardManager.shared.history.firstIndex(where: { $0.id == item.id }) {
            ClipboardManager.shared.removeItem(at: real)
        }
    }
}

// MARK: - Row View

class ClipboardRowView: NSTableRowView {
    override func drawBackground(in dirtyRect: NSRect) {
        NSColor.clear.setFill(); dirtyRect.fill()
    }
    override func drawSelection(in dirtyRect: NSRect) {}
}

// MARK: - Cell

class ClipboardCell: NSTableCellView {

    private var previewLabel: NSTextField!
    private var metaLabel:    NSTextField!   // time · type
    private var deleteBtn:    NSButton!
    private var isHovered     = false
    private var indexInTable  = 0
    private var fullContent   = ""
    private var popover:      NSPopover?
    weak var owner: ClipboardCellDelegate?

    override init(frame: NSRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { super.init(coder: coder); build() }

    private func build() {
        wantsLayer = true
        layer?.cornerRadius = 8

        previewLabel = NSTextField(labelWithString: "")
        previewLabel.font = NSFont.systemFont(ofSize: 13)
        previewLabel.textColor = .labelColor
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.maximumNumberOfLines = 1
        addSubview(previewLabel)

        metaLabel = NSTextField(labelWithString: "")
        metaLabel.font = NSFont.systemFont(ofSize: 11)
        metaLabel.textColor = .secondaryLabelColor
        metaLabel.lineBreakMode = .byTruncatingTail
        addSubview(metaLabel)

        deleteBtn = NSButton()
        deleteBtn.image = NSImage(systemSymbolName: "xmark.circle.fill",
                                  accessibilityDescription: "Delete")
        deleteBtn.imageScaling = .scaleProportionallyDown
        deleteBtn.bezelStyle = .inline
        deleteBtn.isBordered = false
        deleteBtn.contentTintColor = NSColor.tertiaryLabelColor
        deleteBtn.alphaValue = 0
        deleteBtn.action = #selector(deleteTapped)
        deleteBtn.target = self
        addSubview(deleteBtn)

        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited],
            owner: self, userInfo: nil))
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height
        let lPad: CGFloat = 12
        let rPad: CGFloat = 10
        let delSize: CGFloat = 16
        let delX = w - delSize - rPad
        let textW = delX - lPad - 6

        previewLabel.frame = NSRect(x: lPad, y: h / 2,         width: textW, height: 18)
        metaLabel.frame    = NSRect(x: lPad, y: h / 2 - 17,    width: textW, height: 15)
        deleteBtn.frame    = NSRect(x: delX, y: (h - delSize) / 2,
                                    width: delSize, height: delSize)
    }

    func configure(with item: ClipboardItem, index: Int, owner: ClipboardCellDelegate) {
        indexInTable = index
        self.owner   = owner
        fullContent  = item.content
        previewLabel.stringValue = item.preview

        let content = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let type: String
        if content.hasPrefix("http://") || content.hasPrefix("https://") { type = "URL" }
        else if content.contains("@") && content.contains(".")            { type = "Email" }
        else                                                               { type = "Text" }
        metaLabel.stringValue = "\(item.formattedDate)  ·  \(type)"
    }

    func flashCopied() {
        let orig = previewLabel.stringValue
        previewLabel.stringValue = "Copied ✓"
        previewLabel.textColor = .systemGreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.previewLabel.stringValue = orig
            self?.previewLabel.textColor = .labelColor
        }
    }

    // MARK: - Hover

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            deleteBtn.animator().alphaValue = 0.7
            layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
        }
        showPopover()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            deleteBtn.animator().alphaValue = 0
            layer?.backgroundColor = NSColor.clear.cgColor
        }
        popover?.close()
        popover = nil
    }

    private func showPopover() {
        guard !fullContent.isEmpty, popover == nil else { return }

        // Limit displayed text to 600 chars to keep the popover reasonable
        let display = fullContent.count > 600
            ? String(fullContent.prefix(600)) + "…"
            : fullContent

        let textView = NSTextView()
        textView.string = display
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // Measure natural size, cap height
        let maxW: CGFloat = 300
        let maxH: CGFloat = 220
        textView.frame = NSRect(x: 0, y: 0, width: maxW, height: maxH)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let used = textView.layoutManager!.usedRect(for: textView.textContainer!)
        let naturalH = min(used.height + 20, maxH)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: maxW, height: naturalH))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = naturalH == maxH
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let vc = NSViewController()
        vc.view = scrollView
        vc.view.frame = NSRect(x: 0, y: 0, width: maxW, height: naturalH)

        let pop = NSPopover()
        pop.contentViewController = vc
        pop.contentSize = NSSize(width: maxW, height: naturalH)
        pop.behavior = .transient
        pop.animates = false
        pop.show(relativeTo: bounds, of: self, preferredEdge: .maxX)
        popover = pop
    }

    @objc private func deleteTapped() { owner?.didRequestDelete(at: indexInTable) }
}
