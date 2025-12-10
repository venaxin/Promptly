import Cocoa
import SwiftUI

protocol BubbleDelegate: AnyObject {
    func bubbleClicked()
    func bubbleDragStarted()
    func bubbleDragEnded()
}

class AppDelegate: NSObject, NSApplicationDelegate, BubbleDelegate, NSWindowDelegate {

    var bubbleWindow: NSPanel!
    var chatPanel: ChatPanelWindow?
    var stylesWindow: ChatPanelWindow?
    var statusItem: NSStatusItem!

    private let chatWidthKey = "ChatPanelWidth"
    private let chatHeightKey = "ChatPanelHeight"

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
        bubbleWindow.level = .statusBar
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

    // MARK: - Chat Panel

    private func ensureChatPanel() {
        if chatPanel != nil { return }

        let defaultSize = NSSize(width: 430, height: 260)

        let savedWidth = UserDefaults.standard.double(forKey: chatWidthKey)
        let savedHeight = UserDefaults.standard.double(forKey: chatHeightKey)

        let initialSize = NSSize(
            width: savedWidth > 0 ? savedWidth : defaultSize.width,
            height: savedHeight > 0 ? savedHeight : defaultSize.height
        )

        chatPanel = ChatPanelWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
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
        chatPanel.delegate = self
        chatPanel.contentMinSize = defaultSize

        let view = ChatPanelView(frame: NSRect(origin: .zero, size: initialSize))
        view.wantsLayer = true
        view.onManageStyles = { [weak self] in
            self?.showStylesWindow()
        }

        chatPanel.contentView = view
    }

    private func toggleChatPanel() {
        ensureChatPanel()

        guard let chatPanel = chatPanel else { return }

        if chatPanel.isVisible {
            hideChatPanel()
        } else {
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
            panelOrigin.x = bubbleFrame.minX - panelSize.width - padding
            panelOrigin.y = bubbleFrame.maxY - panelSize.height
        } else if minDist == distLeft {
            panelOrigin.x = bubbleFrame.maxX + padding
            panelOrigin.y = bubbleFrame.maxY - panelSize.height
        } else if minDist == distTop {
            panelOrigin.y = bubbleFrame.minY - panelSize.height - padding
            panelOrigin.x = bubbleFrame.maxX - panelSize.width
        } else {
            panelOrigin.y = bubbleFrame.maxY + padding
            panelOrigin.x = bubbleFrame.maxX - panelSize.width
        }

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

    // MARK: - Styles Window

    private func ensureStylesWindow() {
        if stylesWindow != nil { return }

        let size = NSSize(width: 520, height: 320)
        stylesWindow = ChatPanelWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        guard let stylesWindow = stylesWindow else { return }

        stylesWindow.isOpaque = false
        stylesWindow.backgroundColor = .clear
        stylesWindow.hasShadow = true
        stylesWindow.level = .statusBar
        stylesWindow.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        stylesWindow.isReleasedWhenClosed = false
        stylesWindow.delegate = self
        stylesWindow.contentMinSize = size

        let view = ManageStylesView(frame: NSRect(origin: .zero, size: size))
        view.wantsLayer = true
        stylesWindow.contentView = view
    }

    private func showStylesWindow() {
        ensureStylesWindow()
        guard let stylesWindow = stylesWindow,
              let screen = bubbleWindow.screen else { return }

        NSApp.activate(ignoringOtherApps: true)

        let size = stylesWindow.frame.size
        let screenFrame = screen.visibleFrame
        let origin = NSPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2
        )

        stylesWindow.setFrame(NSRect(origin: origin, size: size), display: true, animate: true)
        stylesWindow.orderFrontRegardless()
        stylesWindow.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === chatPanel else { return }

        let size = window.frame.size
        UserDefaults.standard.set(size.width, forKey: chatWidthKey)
        UserDefaults.standard.set(size.height, forKey: chatHeightKey)
    }

    // MARK: - Spaces change

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        bubbleWindow?.orderFrontRegardless()

        if let panel = chatPanel, panel.isVisible {
            panel.orderFrontRegardless()
        }
        if let styles = stylesWindow, styles.isVisible {
            styles.orderFrontRegardless()
        }
    }
}
