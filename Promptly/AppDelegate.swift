import Cocoa
import SwiftUI

protocol BubbleDelegate: AnyObject {
    func bubbleClicked()
    func bubbleDragStarted()
    func bubbleDragEnded()
}

class AppDelegate: NSObject, NSApplicationDelegate, BubbleDelegate {

    var bubbleWindow: NSPanel!
    var chatPanel: ChatPanelWindow?
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let bubbleSize = NSSize(width: 60, height: 60)
        let origin = NSPoint(
            x: screenFrame.maxX - bubbleSize.width - 20,
            y: screenFrame.midY - bubbleSize.height / 2
        )

        let windowRect = NSRect(origin: origin, size: bubbleSize)

        // Bubble = non-activating overlay panel
        bubbleWindow = NSPanel(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        bubbleWindow.isOpaque = false
        bubbleWindow.backgroundColor = .clear
        bubbleWindow.hasShadow = true

        // Above normal app windows, including fullscreen
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

        // Keep windows visible across Space changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        // Status bar item (menu bar icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "p.circle.fill", accessibilityDescription: "Promptly") {
                button.image = image
            } else {
                button.title = "P"
            }
            button.target = self
            button.action = #selector(statusItemClicked(_:))
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running even if no normal windows
        false
    }

    // MARK: - Status item

    @objc private func statusItemClicked(_ sender: Any?) {
        toggleChatPanel()
    }

    // MARK: - BubbleDelegate

    func bubbleClicked() {
        toggleChatPanel()
    }

    func bubbleDragStarted() {
        hideChatPanel()
    }

    func bubbleDragEnded() {
        // no-op
    }

    // MARK: - Chat Panel Management

    private func ensureChatPanel() {
        if chatPanel != nil { return }

        let panelSize = NSSize(width: 320, height: 260)

        // Chat panel: NSPanel subclass that can become key, but still non-activating style
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
            // Bring Promptly to the front in current Space
            NSApp.activate(ignoringOtherApps: true)

            positionChatPanel()
            chatPanel.orderFrontRegardless()
            chatPanel.makeKeyAndOrderFront(nil)

            if let view = chatPanel.contentView as? ChatPanelView {
                chatPanel.makeFirstResponder(view.inputTextView)
            }
        }
    }

    private func hideChatPanel() {
        chatPanel?.orderOut(nil)
    }

    // MARK: - Positioning relative to bubble

    private func positionChatPanel() {
        guard let chatPanel = chatPanel,
              let screen = bubbleWindow.screen else { return }

        let screenFrame = screen.visibleFrame
        let bubbleFrame = bubbleWindow.frame
        let panelSize = chatPanel.frame.size

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
            // Bubble on right edge → panel to the left
            panelOrigin.x = bubbleFrame.minX - panelSize.width - padding
            panelOrigin.y = bubbleFrame.maxY - panelSize.height
        } else if minDist == distLeft {
            // Bubble on left edge → panel to the right
            panelOrigin.x = bubbleFrame.maxX + padding
            panelOrigin.y = bubbleFrame.maxY - panelSize.height
        } else if minDist == distTop {
            // Bubble on top → panel below
            panelOrigin.y = bubbleFrame.minY - panelSize.height - padding
            panelOrigin.x = bubbleFrame.maxX - panelSize.width
        } else {
            // Bubble on bottom → panel above
            panelOrigin.y = bubbleFrame.maxY + padding
            panelOrigin.x = bubbleFrame.maxX - panelSize.width
        }

        // Keep panel inside screen bounds
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

    // MARK: - Spaces change

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        // Keep bubble always on top
        bubbleWindow?.orderFrontRegardless()

        // Only bring chat panel forward if it's visible
        if let panel = chatPanel, panel.isVisible {
            panel.orderFrontRegardless()
        }
    }
}
