//
//  PromptStyle.swift
//  Promptly
//
//  Created by Abdul Rahman on 12/10/25.
//


import Foundation

struct PromptStyle: Codable, Equatable {
    var name: String
    var instruction: String
}

extension Notification.Name {
    static let promptStylesUpdated = Notification.Name("PromptStylesUpdated")
}

class PromptStyleManager {
    static let shared = PromptStyleManager()

    private let storageKey = "PromptStyles"

    private(set) var styles: [PromptStyle] {
        didSet {
            save()
            NotificationCenter.default.post(name: .promptStylesUpdated, object: nil)
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([PromptStyle].self, from: data),
           !decoded.isEmpty {
            styles = decoded
        } else {
            styles = [
                PromptStyle(
                    name: "Default",
                    instruction: "Use a neutral, clear style that balances structure and brevity."
                ),
                PromptStyle(
                    name: "Concise",
                    instruction: "Make the rewritten prompt as concise and minimal as possible while keeping all important constraints and requirements."
                ),
                PromptStyle(
                    name: "Detailed",
                    instruction: "Expand structure and clarify assumptions. Prefer detailed bullet points, explicit constraints, and step-by-step tasks that make the prompt easy for an AI to follow."
                ),
                PromptStyle(
                    name: "Code Helper",
                    instruction: "Optimize the prompt for coding help. Emphasize clear input/output expectations, examples, edge cases, and any specific libraries, versions, or platforms involved."
                )
            ]
            save()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(styles) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func update(style: PromptStyle, at index: Int) {
        guard styles.indices.contains(index) else { return }
        styles[index] = style
    }

    func add(style: PromptStyle) {
        styles.append(style)
    }

    func remove(at index: Int) {
        guard styles.indices.contains(index) else { return }
        // Do not allow removing the first built-in "Default" style
        if index == 0 { return }
        styles.remove(at: index)
    }
}
