import Cocoa

class DraggableSnapView: NSView {

    weak var delegate: BubbleDelegate?

    private var dragOffset: NSPoint = .zero
    private var initialMouseDownLocation: NSPoint = .zero
    private var isDragging = false

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }

        isDragging = false

        let mouseLocation = NSEvent.mouseLocation
        initialMouseDownLocation = mouseLocation

        let windowOrigin = window.frame.origin
        dragOffset = NSPoint(
            x: mouseLocation.x - windowOrigin.x,
            y: mouseLocation.y - windowOrigin.y
        )
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window,
              let screen = window.screen else { return }

        let currentLocation = NSEvent.mouseLocation
        let dx = currentLocation.x - initialMouseDownLocation.x
        let dy = currentLocation.y - initialMouseDownLocation.y

        if !isDragging && (abs(dx) > 3 || abs(dy) > 3) {
            isDragging = true
            delegate?.bubbleDragStarted()
        }

        guard isDragging else { return }

        let screenFrame = screen.visibleFrame

        var newOrigin = currentLocation
        newOrigin.x -= dragOffset.x
        newOrigin.y -= dragOffset.y

        var frame = window.frame
        frame.origin = newOrigin

        // Keep the bubble entirely on screen.
        if frame.minX < screenFrame.minX { frame.origin.x = screenFrame.minX }
        if frame.maxX > screenFrame.maxX { frame.origin.x = screenFrame.maxX - frame.width }
        if frame.minY < screenFrame.minY { frame.origin.y = screenFrame.minY }
        if frame.maxY > screenFrame.maxY { frame.origin.y = screenFrame.maxY - frame.height }

        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            snapToNearestEdge()
            delegate?.bubbleDragEnded()
        } else {
            // Click, not drag.
            delegate?.bubbleClicked()
        }
    }

    // MARK: - Edge Snap

    private func snapToNearestEdge() {
        guard let window = self.window,
              let screen = window.screen else { return }

        let screenFrame = screen.visibleFrame
        var frame = window.frame

        let centerX = frame.midX
        let centerY = frame.midY

        let distLeft   = abs(centerX - screenFrame.minX)
        let distRight  = abs(screenFrame.maxX - centerX)
        let distBottom = abs(centerY - screenFrame.minY)
        let distTop    = abs(screenFrame.maxY - centerY)

        let minDist = min(distLeft, distRight, distBottom, distTop)

        if minDist == distLeft {
            frame.origin.x = screenFrame.minX
        } else if minDist == distRight {
            frame.origin.x = screenFrame.maxX - frame.width
        } else if minDist == distBottom {
            frame.origin.y = screenFrame.minY
        } else {
            frame.origin.y = screenFrame.maxY - frame.height
        }

        window.animator().setFrame(frame, display: true)
    }

    // MARK: - Drawing (bubble only)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let diameter: CGFloat = 52
        let bubbleRect = NSRect(
            x: bounds.midX - diameter / 2,
            y: bounds.midY - diameter / 2,
            width: diameter,
            height: diameter
        )

        NSColor.systemBlue.setFill()
        let path = NSBezierPath(ovalIn: bubbleRect)
        path.fill()

        let text = "P"
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 24, weight: .semibold)
        ]

        let size = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: bubbleRect.midX - size.width / 2,
            y: bubbleRect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        text.draw(in: textRect, withAttributes: attributes)
    }
}
