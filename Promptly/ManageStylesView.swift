//
//  ManageStylesView.swift
//  Promptly
//
//  Created by Abdul Rahman on 12/10/25.
//


import Cocoa

class ManageStylesView: NSView {

    private let stylesPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let nameField = NSTextField(string: "")
    private let originalTextView = NSTextView()
    private let improvedTextView = NSTextView()

    private let addButton = NSButton(title: "+", target: nil, action: nil)
    private let removeButton = NSButton(title: "−", target: nil, action: nil)
    private let improveButton = NSButton(title: "Improve description", target: nil, action: nil)
    private let useOriginalButton = NSButton(title: "Use original", target: nil, action: nil)
    private let useImprovedButton = NSButton(title: "Use improved", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save style", target: nil, action: nil)

    private let gemini = GeminiClient()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.97).cgColor
        layer?.cornerRadius = 12
        translatesAutoresizingMaskIntoConstraints = false

        let originalScroll = NSScrollView()
        originalScroll.borderType = .bezelBorder
        originalScroll.hasVerticalScroller = true
        originalScroll.translatesAutoresizingMaskIntoConstraints = false
        originalScroll.documentView = originalTextView

        let improvedScroll = NSScrollView()
        improvedScroll.borderType = .bezelBorder
        improvedScroll.hasVerticalScroller = true
        improvedScroll.translatesAutoresizingMaskIntoConstraints = false
        improvedScroll.documentView = improvedTextView

        nameField.translatesAutoresizingMaskIntoConstraints = false

        originalTextView.isRichText = false
        originalTextView.font = NSFont.systemFont(ofSize: 12)

        improvedTextView.isRichText = false
        improvedTextView.font = NSFont.systemFont(ofSize: 12)
        improvedTextView.isEditable = false

        stylesPopup.translatesAutoresizingMaskIntoConstraints = false
        reloadStylesPopup()

        addButton.bezelStyle = .rounded
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.target = self
        addButton.action = #selector(addTapped)

        removeButton.bezelStyle = .rounded
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.target = self
        removeButton.action = #selector(removeTapped)

        improveButton.bezelStyle = .rounded
        improveButton.translatesAutoresizingMaskIntoConstraints = false
        improveButton.target = self
        improveButton.action = #selector(improveTapped)

        useOriginalButton.bezelStyle = .rounded
        useOriginalButton.translatesAutoresizingMaskIntoConstraints = false
        useOriginalButton.target = self
        useOriginalButton.action = #selector(useOriginalTapped)

        useImprovedButton.bezelStyle = .rounded
        useImprovedButton.translatesAutoresizingMaskIntoConstraints = false
        useImprovedButton.target = self
        useImprovedButton.action = #selector(useImprovedTapped)

        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.target = self
        saveButton.action = #selector(saveTapped)

        stylesPopup.target = self
        stylesPopup.action = #selector(styleSelectionChanged(_:))

        addSubview(stylesPopup)
        addSubview(addButton)
        addSubview(removeButton)
        addSubview(nameField)
        addSubview(originalScroll)
        addSubview(improvedScroll)
        addSubview(improveButton)
        addSubview(useOriginalButton)
        addSubview(useImprovedButton)
        addSubview(saveButton)

        NSLayoutConstraint.activate([
            stylesPopup.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stylesPopup.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),

            addButton.centerYAnchor.constraint(equalTo: stylesPopup.centerYAnchor),
            addButton.leadingAnchor.constraint(equalTo: stylesPopup.trailingAnchor, constant: 6),

            removeButton.centerYAnchor.constraint(equalTo: stylesPopup.centerYAnchor),
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 6),

            nameField.topAnchor.constraint(equalTo: stylesPopup.bottomAnchor, constant: 8),
            nameField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            nameField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            nameField.heightAnchor.constraint(equalToConstant: 22),

            originalScroll.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 8),
            originalScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            originalScroll.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5, constant: -15),
            originalScroll.bottomAnchor.constraint(equalTo: improveButton.topAnchor, constant: -8),

            improvedScroll.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 8),
            improvedScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            improvedScroll.leadingAnchor.constraint(equalTo: originalScroll.trailingAnchor, constant: 10),
            improvedScroll.bottomAnchor.constraint(equalTo: improveButton.topAnchor, constant: -8),

            improveButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            improveButton.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -8),

            useOriginalButton.centerYAnchor.constraint(equalTo: improveButton.centerYAnchor),
            useOriginalButton.centerXAnchor.constraint(equalTo: centerXAnchor),

            useImprovedButton.centerYAnchor.constraint(equalTo: improveButton.centerYAnchor),
            useImprovedButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            saveButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            saveButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stylesUpdated),
            name: .promptStylesUpdated,
            object: nil
        )

        loadSelectedStyle()
    }

    private func currentStyles() -> [PromptStyle] {
        PromptStyleManager.shared.styles
    }

    private func reloadStylesPopup() {
        stylesPopup.removeAllItems()
        let names = currentStyles().map { $0.name }
        stylesPopup.addItems(withTitles: names)
        if stylesPopup.numberOfItems > 0 {
            stylesPopup.selectItem(at: 0)
        }
    }

    private func selectedIndex() -> Int? {
        let idx = stylesPopup.indexOfSelectedItem
        let styles = currentStyles()
        guard styles.indices.contains(idx) else { return nil }
        return idx
    }

    private func loadSelectedStyle() {
        guard let idx = selectedIndex() else {
            nameField.stringValue = ""
            originalTextView.string = ""
            improvedTextView.string = ""
            return
        }
        let style = currentStyles()[idx]
        nameField.stringValue = style.name
        originalTextView.string = style.instruction
        improvedTextView.string = ""
    }

    @objc private func styleSelectionChanged(_ sender: NSPopUpButton) {
        loadSelectedStyle()
    }

    @objc private func stylesUpdated() {
        // Keep selection index if possible
        let previousIndex = stylesPopup.indexOfSelectedItem
        reloadStylesPopup()
        if currentStyles().indices.contains(previousIndex) {
            stylesPopup.selectItem(at: previousIndex)
        }
        loadSelectedStyle()
    }

    @objc private func addTapped() {
        let newStyle = PromptStyle(
            name: "New Style \(currentStyles().count + 1)",
            instruction: "Describe how this style should rewrite prompts."
        )
        PromptStyleManager.shared.add(style: newStyle)
        reloadStylesPopup()
        stylesPopup.selectItem(at: currentStyles().count - 1)
        loadSelectedStyle()
    }

    @objc private func removeTapped() {
        guard let idx = selectedIndex() else { return }
        // Manager prevents removing index 0
        PromptStyleManager.shared.remove(at: idx)
        reloadStylesPopup()
        loadSelectedStyle()
    }

    @objc private func improveTapped() {
        let text = originalTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        improveButton.isEnabled = false
        let oldTitle = improveButton.title
        improveButton.title = "Improving…"

        gemini.improveStyleDescription(text: text) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.improveButton.isEnabled = true
                self.improveButton.title = oldTitle

                switch result {
                case .success(let improved):
                    self.improvedTextView.string = improved
                case .failure(let error):
                    self.improvedTextView.string = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    @objc private func useOriginalTapped() {
        improvedTextView.string = originalTextView.string
    }

    @objc private func useImprovedTapped() {
        let improved = improvedTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !improved.isEmpty else { return }
        originalTextView.string = improved
    }

    @objc private func saveTapped() {
        guard let idx = selectedIndex() else { return }

        let trimmedName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = currentStyles()[idx]

        let updated = PromptStyle(
            name: trimmedName.isEmpty ? current.name : trimmedName,
            instruction: originalTextView.string
        )

        PromptStyleManager.shared.update(style: updated, at: idx)
        reloadStylesPopup()
        stylesPopup.selectItem(at: idx)
    }
}

