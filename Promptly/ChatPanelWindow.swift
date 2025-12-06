import AppKit

class ChatPanelWindow: NSPanel {
    // Even though styleMask contains .nonactivatingPanel,
    // we explicitly allow this window to become key/main
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
