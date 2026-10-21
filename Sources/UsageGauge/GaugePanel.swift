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

    /// Keeps the top-left corner fixed while the content grows or shrinks.
    func fitContent() {
        guard let size = contentView?.fittingSize, size != frame.size else { return }
        let topLeft = NSPoint(x: frame.minX, y: frame.maxY)
        setContentSize(size)
        setFrameTopLeftPoint(topLeft)
    }

    private func placeTopLeft() {
        guard let visible = NSScreen.main?.visibleFrame else { return }
        setFrameTopLeftPoint(NSPoint(x: visible.minX + Self.screenMargin, y: visible.maxY - Self.screenMargin))
    }
}
