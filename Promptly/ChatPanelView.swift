import Cocoa

class ChatPanelView: NSView {

    // Exposed so AppDelegate can focus it
    let inputTextView = NSTextView()
    private let outputTextView = NSTextView()
    private let improveButton = NSButton(title: "Improve", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)

    private let stylePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let autoCopyCheckbox = NSButton(checkboxWithTitle: "Auto-copy after Improve", target: nil, action: nil)
    private let historyPopup = NSPopUpButton(frame: .zero, pullsDown: false)

    private let gemini = GeminiClient()

    private struct HistoryItem {
        let input: String
        let output: String
        let style: String
    }

    private var history: [HistoryItem] = [] {
        didSet { reloadHistoryPopup() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        layer?.cornerRadius = 12

        translatesAutoresizingMaskIntoConstraints = false

        // Scroll views
        let inputScroll = NSScrollView()
        inputScroll.borderType = .bezelBorder
        inputScroll.hasVerticalScroller = true
        inputScroll.translatesAutoresizingMaskIntoConstraints = false
        inputScroll.documentView = inputTextView

        let outputScroll = NSScrollView()
        outputScroll.borderType = .bezelBorder
        outputScroll.hasVerticalScroller = true
        outputScroll.translatesAutoresizingMaskIntoConstraints = false
        outputScroll.documentView = outputTextView

        inputTextView.isRichText = false
        inputTextView.font = NSFont.systemFont(ofSize: 13)

        outputTextView.isRichText = false
        outputTextView.isEditable = false
        outputTextView.font = NSFont.systemFont(ofSize: 13)

        // Buttons
        improveButton.target = self
        improveButton.action = #selector(improvePrompt)
        improveButton.bezelStyle = .rounded
        improveButton.translatesAutoresizingMaskIntoConstraints = false

        copyButton.target = self
        copyButton.action = #selector(copyOutput)
        copyButton.bezelStyle = .rounded
        copyButton.translatesAutoresizingMaskIntoConstraints = false

        // Style popup
        stylePopup.translatesAutoresizingMaskIntoConstraints = false
        stylePopup.addItems(withTitles: [
            "Default",
            "Concise",
            "Detailed",
            "Code Helper"
        ])
        stylePopup.selectItem(withTitle: "Default")

        // Auto-copy checkbox
        autoCopyCheckbox.target = self
        autoCopyCheckbox.action = #selector(autoCopyToggled(_:))
        autoCopyCheckbox.translatesAutoresizingMaskIntoConstraints = false
        autoCopyCheckbox.state = .off

        // History popup
        historyPopup.translatesAutoresizingMaskIntoConstraints = false
        historyPopup.target = self
        historyPopup.action = #selector(historySelectionChanged(_:))
        reloadHistoryPopup()

        addSubview(inputScroll)
        addSubview(stylePopup)
        addSubview(autoCopyCheckbox)
        addSubview(improveButton)
        addSubview(historyPopup)
        addSubview(copyButton)
        addSubview(outputScroll)

        NSLayoutConstraint.activate([
            // Input
            inputScroll.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            inputScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            inputScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            inputScroll.heightAnchor.constraint(equalToConstant: 80),

            // Style popup (left)
            stylePopup.topAnchor.constraint(equalTo: inputScroll.bottomAnchor, constant: 6),
            stylePopup.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),

            // Auto-copy (right)
            autoCopyCheckbox.centerYAnchor.constraint(equalTo: stylePopup.centerYAnchor),
            autoCopyCheckbox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            // Improve button (left)
            improveButton.topAnchor.constraint(equalTo: stylePopup.bottomAnchor, constant: 6),
            improveButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),

            // Copy button (right)
            copyButton.centerYAnchor.constraint(equalTo: improveButton.centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            // History popup between Improve and Copy
            historyPopup.centerYAnchor.constraint(equalTo: improveButton.centerYAnchor),
            historyPopup.leadingAnchor.constraint(equalTo: improveButton.trailingAnchor, constant: 6),
            historyPopup.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -6),

            // Output
            outputScroll.topAnchor.constraint(equalTo: improveButton.bottomAnchor, constant: 8),
            outputScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            outputScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            outputScroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    // MARK: - History

    private func reloadHistoryPopup() {
        historyPopup.removeAllItems()
        historyPopup.addItem(withTitle: "History")

        for (index, item) in history.enumerated() {
            let preview = item.output
                .replacingOccurrences(of: "\n", with: " ")
                .prefix(30)
            let title = "\(index + 1): [\(item.style)] \(preview)"
            historyPopup.addItem(withTitle: String(title))
        }

        historyPopup.selectItem(at: 0)
    }

    private func addHistoryEntry(input: String, output: String, style: String) {
        let item = HistoryItem(input: input, output: output, style: style)
        history.insert(item, at: 0)
        if history.count > 10 {
            history.removeLast()
        }
    }

    @objc private func historySelectionChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index > 0, index - 1 < history.count else { return }

        let item = history[index - 1]
        inputTextView.string = item.input
        outputTextView.string = item.output

        if let styleItem = stylePopup.item(withTitle: item.style) {
            stylePopup.select(styleItem)
        }
    }

    // MARK: - Actions

    @objc private func autoCopyToggled(_ sender: NSButton) {
        // no-op: we read state in improvePrompt
    }

    @objc private func copyOutput() {
        let text = outputTextView.string
        guard !text.isEmpty else { return }

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    @objc private func improvePrompt() {
        let original = inputTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !original.isEmpty else {
            outputTextView.string = "Type a prompt above, then click Improve."
            return
        }

        let selectedStyle = stylePopup.titleOfSelectedItem ?? "Default"

        improveButton.isEnabled = false
        let oldTitle = improveButton.title
        improveButton.title = "Improving..."
        outputTextView.string = "Calling Gemini…"

        gemini.improvePrompt(raw: original, style: selectedStyle) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.improveButton.isEnabled = true
                self.improveButton.title = oldTitle

                switch result {
                case .success(let rewritten):
                    self.outputTextView.string = rewritten

                    // Add to history
                    self.addHistoryEntry(input: original, output: rewritten, style: selectedStyle)

                    // Auto-copy if enabled
                    if self.autoCopyCheckbox.state == .on {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(rewritten, forType: .string)
                    }

                case .failure(let error):
                    self.outputTextView.string = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
