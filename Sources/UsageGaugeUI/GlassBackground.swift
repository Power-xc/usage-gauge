import AppKit
import SwiftUI

/// Clear smoked Liquid Glass on macOS 26, a dark vibrancy blur before that. Clear glass has no
/// milky frost, so the pane reads as dark glass rather than grey.
public struct GlassBackground: ViewModifier {
    let tintOpacity: Double

    /// - Parameter tintOpacity: how dark the smoke is; deeper keeps type legible over bright content.
    public init(tintOpacity: Double = 0.42) {
        self.tintOpacity = tintOpacity
    }

    private static let layerShare = 0.85

    private let shape = RoundedRectangle(cornerRadius: Theme.panelCornerRadius, style: .continuous)

    public func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                // Clear smoked glass: what is behind shows through without a grey frost. The ink
                // layer under the type keeps it legible over bright content.
                .background(shape.fill(Theme.smoke.opacity(tintOpacity * Self.layerShare)))
                .glassEffect(.clear.tint(Theme.smoke.opacity(tintOpacity)), in: shape)
                .overlay(GlassSheen(shape: shape))
                .overlay(GlassSlabEdge(shape: shape))
        } else {
            content
                .background(VibrancyBlur().overlay(Theme.smoke.opacity(tintOpacity)))
                .clipShape(shape)
                .overlay(GlassSheen(shape: shape))
                .overlay(GlassSlabEdge(shape: shape))
        }
    }
}

/// Edge of a glass slab: one flat 1 pt line.
public struct GlassSlabEdge<S: InsettableShape>: View {
    let shape: S

    public init(shape: S) {
        self.shape = shape
    }

    public var body: some View {
        shape.strokeBorder(.white.opacity(0.16), lineWidth: 1)
    }
}

/// A faint flat hairline just inside the slab's edge that gives the pane its depth.
public struct GlassSheen<S: InsettableShape>: View {
    let shape: S

    public init(shape: S) {
        self.shape = shape
    }

    public var body: some View {
        shape.inset(by: 1.5).strokeBorder(.white.opacity(0.04), lineWidth: 1)
            .allowsHitTesting(false)
    }
}

private struct VibrancyBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
