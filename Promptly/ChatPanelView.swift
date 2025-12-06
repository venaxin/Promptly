import Cocoa

class ChatPanelView: NSView {

    // Exposed so AppDelegate can focus it
    let inputTextView = NSTextView()
    private let outputTextView = NSTextView()
    private let improveButton = NSButton(title: "Improve", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)

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

        improveButton.target = self
        improveButton.action = #selector(improvePrompt)
        improveButton.bezelStyle = .rounded
        improveButton.translatesAutoresizingMaskIntoConstraints = false

        copyButton.target = self
        copyButton.action = #selector(copyOutput)
        copyButton.bezelStyle = .rounded
        copyButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(inputScroll)
        addSubview(improveButton)
        addSubview(copyButton)
        addSubview(outputScroll)

        NSLayoutConstraint.activate([
            inputScroll.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            inputScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            inputScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            inputScroll.heightAnchor.constraint(equalToConstant: 80),

            // Improve button (left)
            improveButton.topAnchor.constraint(equalTo: inputScroll.bottomAnchor, constant: 8),
            improveButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),

            // Copy button (right, same vertical position)
            copyButton.centerYAnchor.constraint(equalTo: improveButton.centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            outputScroll.topAnchor.constraint(equalTo: improveButton.bottomAnchor, constant: 8),
            outputScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            outputScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            outputScroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
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

        improveButton.isEnabled = false
        let oldTitle = improveButton.title
        improveButton.title = "Improving..."
        outputTextView.string = "Calling Gemini…"

        gemini.improvePrompt(raw: original) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.improveButton.isEnabled = true
                self.improveButton.title = oldTitle

                switch result {
                case .success(let rewritten):
                    self.outputTextView.string = rewritten
                case .failure(let error):
                    self.outputTextView.string = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
