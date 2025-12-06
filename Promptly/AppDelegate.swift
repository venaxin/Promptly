import Cocoa
import SwiftUI

protocol BubbleDelegate: AnyObject {
    func bubbleClicked()
    func bubbleDragStarted()
    func bubbleDragEnded()
}

class AppDelegate: NSObject, NSApplicationDelegate, BubbleDelegate {

    var bubbleWindow: NSPanel!
    var chatPanel: ChatPanelWindow?    // ⬅️ use subclass

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let bubbleSize = NSSize(width: 60, height: 60)
        let origin = NSPoint(
            x: screenFrame.maxX - bubbleSize.width - 20,
            y: screenFrame.midY - bubbleSize.height / 2
        )

        let windowRect = NSRect(origin: origin, size: bubbleSize)

        bubbleWindow = NSPanel(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        bubbleWindow.isOpaque = false
        bubbleWindow.backgroundColor = .clear
        bubbleWindow.hasShadow = true

        // Sits above normal app windows, including most full-screen content
        bubbleWindow.level = .statusBar

        // Show on all Spaces and with fullscreen apps
        bubbleWindow.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        let contentView = DraggableSnapView(frame: NSRect(origin: .zero, size: bubbleSize))
        contentView.wantsLayer = true
        contentView.delegate = self

        bubbleWindow.contentView = contentView
        bubbleWindow.isMovableByWindowBackground = false
        bubbleWindow.isReleasedWhenClosed = false

        bubbleWindow.orderFrontRegardless()

        // Listen for Space changes so we can bring it forward again
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - BubbleDelegate

    func bubbleClicked() {
        toggleChatPanel()
    }

    func bubbleDragStarted() {
        // Hide chat while dragging so it doesn't float awkwardly.
        hideChatPanel()
    }

    func bubbleDragEnded() {
        // If you ever want chat to re-open after drag, you could handle it here.
    }

    // MARK: - Chat Panel Management

    private func ensureChatPanel() {
        if chatPanel != nil { return }

        let panelSize = NSSize(width: 280, height: 220)

        // ⬇️ Use ChatPanelWindow, KEEP .nonactivatingPanel so visibility stays as you liked
        chatPanel = ChatPanelWindow(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        guard let chatPanel = chatPanel else { return }

        chatPanel.isOpaque = false
        chatPanel.backgroundColor = .clear
        chatPanel.hasShadow = true
        chatPanel.level = .statusBar
        chatPanel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        chatPanel.isReleasedWhenClosed = false

        let view = ChatPanelView(frame: NSRect(origin: .zero, size: panelSize))
        view.wantsLayer = true
        chatPanel.contentView = view
    }

    private func toggleChatPanel() {
        ensureChatPanel()

        guard let chatPanel = chatPanel else { return }

        if chatPanel.isVisible {
            hideChatPanel()
        } else {
            // 1) Bring Promptly to front on the current Space/fullscreen
            NSApp.activate(ignoringOtherApps: true)

            // 2) Position the panel next to the bubble
            positionChatPanel()

            // 3) Show and make it key
            chatPanel.orderFrontRegardless()
            chatPanel.makeKeyAndOrderFront(nil)

            // 4) Focus the input text view (now allowed because of ChatPanelWindow overrides)
            if let view = chatPanel.contentView as? ChatPanelView {
                chatPanel.makeFirstResponder(view.inputTextView)
            }
        }
    }

    private func hideChatPanel() {
        chatPanel?.orderOut(nil)
    }

    // MARK: - Adaptive Positioning

    private func positionChatPanel() {
        guard let chatPanel = chatPanel,
              let screen = bubbleWindow.screen else { return }

        let screenFrame = screen.visibleFrame
        let bubbleFrame = bubbleWindow.frame
        let panelSize = chatPanel.frame.size

        // Decide which edge the bubble is closest to (same logic as snap).
        let centerX = bubbleFrame.midX
        let centerY = bubbleFrame.midY

        let distLeft   = abs(centerX - screenFrame.minX)
        let distRight  = abs(screenFrame.maxX - centerX)
        let distBottom = abs(centerY - screenFrame.minY)
        let distTop    = abs(screenFrame.maxY - centerY)

        let minDist = min(distLeft, distRight, distBottom, distTop)

        var panelOrigin = NSPoint.zero
        let padding: CGFloat = 8

        if minDist == distRight {
            // Bubble is on the right edge -> open panel to the LEFT of the bubble.
            panelOrigin.x = bubbleFrame.minX - panelSize.width - padding
            panelOrigin.y = bubbleFrame.maxY - panelSize.height   // align tops
        } else if minDist == distLeft {
            // Bubble on left edge -> panel to the RIGHT.
            panelOrigin.x = bubbleFrame.maxX + padding
            panelOrigin.y = bubbleFrame.maxY - panelSize.height
        } else if minDist == distTop {
            // Bubble at top -> panel BELOW the bubble.
            panelOrigin.y = bubbleFrame.minY - panelSize.height - padding
            panelOrigin.x = bubbleFrame.maxX - panelSize.width    // align right
        } else {
            // Bubble at bottom -> panel ABOVE the bubble.
            panelOrigin.y = bubbleFrame.maxY + padding
            panelOrigin.x = bubbleFrame.maxX - panelSize.width    // align right
        }

        // Keep panel inside screen bounds (optional but nice).
        if panelOrigin.x < screenFrame.minX {
            panelOrigin.x = screenFrame.minX + padding
        }
        if panelOrigin.x + panelSize.width > screenFrame.maxX {
            panelOrigin.x = screenFrame.maxX - panelSize.width - padding
        }
        if panelOrigin.y < screenFrame.minY {
            panelOrigin.y = screenFrame.minY + padding
        }
        if panelOrigin.y + panelSize.height > screenFrame.maxY {
            panelOrigin.y = screenFrame.maxY - panelSize.height - padding
        }

        let newFrame = NSRect(origin: panelOrigin, size: panelSize)
        chatPanel.setFrame(newFrame, display: true, animate: true)
    }

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        // Re-order the bubble (and chat panel if visible) to the front on the new Space
        bubbleWindow?.orderFrontRegardless()
        chatPanel?.orderFrontRegardless()
    }
}
