import AppKit
import SwiftUI

/// Borderless, non-activating panel that floats above other apps and every Space.
final class GaugePanel: NSPanel {
    private static let autosaveName = "UsageGaugePanel"
    private static let screenMargin: CGFloat = 12

    init(contentView view: NSView) {
        super.init(contentRect: NSRect(origin: .zero, size: view.fittingSize),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        contentView = view
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        hidesOnDeactivate = false
        // On macOS 15+ the header and provider grid move the window with WindowDragGesture, leaving
        // the opacity bar's row alone; dragging anywhere on the background would steal its drags.
        if #unavailable(macOS 15) { isMovableByWindowBackground = true }
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        appearance = NSAppearance(named: .darkAqua)
        setFrameAutosaveName(Self.autosaveName)
        if !setFrameUsingName(Self.autosaveName) { placeTopLeft() }
    }

    override var canBecomeKey: Bool { false }

    /// Keeps the top-left corner fixed while the content grows or shrinks, then nudges the panel
    /// back inside the screen if it grew past an edge.
    func fitContent() {
        if let size = contentView?.fittingSize, size != frame.size {
            let topLeft = NSPoint(x: frame.minX, y: frame.maxY)
            setContentSize(size)
            setFrameTopLeftPoint(topLeft)
        }
        keepOnScreen()
    }

    private func keepOnScreen() {
        guard let visible = (screen ?? NSScreen.main)?.visibleFrame else { return }
        var origin = frame.origin
        origin.x = min(max(origin.x, visible.minX), visible.maxX - frame.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - frame.height)
        if origin != frame.origin { setFrameOrigin(origin) }
    }

    private func placeTopLeft() {
        guard let visible = NSScreen.main?.visibleFrame else { return }
        setFrameTopLeftPoint(NSPoint(x: visible.minX + Self.screenMargin, y: visible.maxY - Self.screenMargin))
    }
}
