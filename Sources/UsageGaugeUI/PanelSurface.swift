import SwiftUI

/// The panel's backing for its style: smoked glass for iris, a flat matte charcoal card for dot, and
/// a black terminal pane with a hairline frame for mono.
public struct PanelSurface: ViewModifier {
    let style: PanelStyle
    let tintOpacity: Double

    /// - Parameter tintOpacity: how dark the iris glass is; the opaque styles ignore it.
    public init(style: PanelStyle, tintOpacity: Double = 0.42) {
        self.style = style
        self.tintOpacity = tintOpacity
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
        switch style {
        case .iris:
            content.modifier(GlassBackground(tintOpacity: tintOpacity))
        case .dot:
            content
                .background(MatteCard(shape: shape))
                .clipShape(shape)
        case .mono:
            content
                .background(shape.fill(Color(white: 0.04).opacity(0.97)))
                .overlay(shape.strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .clipShape(shape)
        }
    }
}

/// Flat charcoal card with a fine rim, like a matte device face. One even tone, so the lit dots are
/// the only light on it.
private struct MatteCard: View {
    let shape: RoundedRectangle

    var body: some View {
        shape.fill(Color(white: 0.1))
            .overlay(shape.strokeBorder(.white.opacity(0.09), lineWidth: 1))
    }
}
