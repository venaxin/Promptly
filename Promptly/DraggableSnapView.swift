import Cocoa

class DraggableSnapView: NSView {

    weak var delegate: BubbleDelegate?

    private var isDragging = false
    private var dragStartLocation: NSPoint = .zero
    private let bubbleImage = NSImage(named: "PromptStatusIcon")

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if let bubbleImage = bubbleImage {
            bubbleImage.draw(in: bounds)
        } else {
            NSColor.systemBlue.setFill()
            let path = NSBezierPath(ovalIn: bounds)
            path.fill()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.boldSystemFont(ofSize: 24),
                .paragraphStyle: paragraph
            ]

            let text = "P" as NSString
            let textSize = text.size(withAttributes: attrs)
            let textRect = NSRect(
                x: (bounds.width - textSize.width) / 2,
                y: (bounds.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attrs)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }

        isDragging = false
        dragStartLocation = window.convertPoint(toScreen: event.locationInWindow)
        // Do NOT call bubbleDragStarted here; only once we detect a real drag.
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window,
              let screen = window.screen else { return }

        let currentLocation = window.convertPoint(toScreen: event.locationInWindow)
        let deltaX = currentLocation.x - dragStartLocation.x
        let deltaY = currentLocation.y - dragStartLocation.y

        if abs(deltaX) > 1 || abs(deltaY) > 1 {
            if !isDragging {
                isDragging = true
                delegate?.bubbleDragStarted()
            }
        }

        var frame = window.frame
        frame.origin.x += deltaX
        frame.origin.y += deltaY

        let visibleFrame = screen.visibleFrame
        let clampedX = max(visibleFrame.minX, min(frame.origin.x, visibleFrame.maxX - frame.size.width))
        let clampedY = max(visibleFrame.minY, min(frame.origin.y, visibleFrame.maxY - frame.size.height))

        frame.origin = NSPoint(x: clampedX, y: clampedY)
        window.setFrame(frame, display: true)

        dragStartLocation = currentLocation
    }

    override func mouseUp(with event: NSEvent) {
        guard let window = self.window,
              let screen = window.screen else { return }

        if isDragging {
            snapWindowToNearestEdge(window: window, screen: screen)
            delegate?.bubbleDragEnded()
        } else {
            delegate?.bubbleClicked()
        }
    }

    private func snapWindowToNearestEdge(window: NSWindow, screen: NSScreen) {
        let frame = window.frame
        let visibleFrame = screen.visibleFrame

        let centerX = frame.midX
        let centerY = frame.midY

        let distLeft   = abs(centerX - visibleFrame.minX)
        let distRight  = abs(visibleFrame.maxX - centerX)
        let distBottom = abs(centerY - visibleFrame.minY)
        let distTop    = abs(visibleFrame.maxY - centerY)

        let minDist = min(distLeft, distRight, distBottom, distTop)

        var newOrigin = frame.origin

        if minDist == distLeft {
            newOrigin.x = visibleFrame.minX
        } else if minDist == distRight {
            newOrigin.x = visibleFrame.maxX - frame.width
        } else if minDist == distBottom {
            newOrigin.y = visibleFrame.minY
        } else {
            newOrigin.y = visibleFrame.maxY - frame.height
        }

        window.setFrameOrigin(newOrigin)
    }
}
