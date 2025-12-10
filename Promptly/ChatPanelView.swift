import Cocoa

class ChatPanelView: NSView {

    // Exposed so AppDelegate can focus it
    let inputTextView = NSTextView()
    private let outputTextView = NSTextView()
    private let improveButton = NSButton(title: "Improve", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)

    private let stylePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let autoCopyCheckbox = NSButton(checkboxWithTitle: "Auto-copy after Improve", target: nil, action: nil)

    private let gemini = GeminiClient()

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

        addSubview(inputScroll)
        addSubview(stylePopup)
        addSubview(autoCopyCheckbox)
        addSubview(improveButton)
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

            // Auto-copy checkbox (right)
            autoCopyCheckbox.centerYAnchor.constraint(equalTo: stylePopup.centerYAnchor),
            autoCopyCheckbox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            // Improve button (left, under style row)
            improveButton.topAnchor.constraint(equalTo: stylePopup.bottomAnchor, constant: 6),
            improveButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),

            // Copy button (right, same row as Improve)
            copyButton.centerYAnchor.constraint(equalTo: improveButton.centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            // Output
            outputScroll.topAnchor.constraint(equalTo: improveButton.bottomAnchor, constant: 8),
            outputScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            outputScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            outputScroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    // MARK: - Actions

    @objc private func autoCopyToggled(_ sender: NSButton) {
        // nothing to do right now; we just read sender.state later
    }

    @objc private func copyOutput() {
        let text = outputTextView.string
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

                    // Auto-copy if option is enabled
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
