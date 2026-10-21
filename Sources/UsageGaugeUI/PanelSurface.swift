import SwiftUI

/// The panel's backing for its style: smoked glass for iris, a matte charcoal card lit warmly from
/// the top-left for dot, and a black terminal pane with a hairline frame for mono.
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

/// Charcoal card with a warm light falling on its top-left corner and a fine lit rim, like a
/// matte device face.
private struct MatteCard: View {
    let shape: RoundedRectangle

    private static let warmLight = Color(red: 1, green: 0.62, blue: 0.38)

    var body: some View {
        shape.fill(LinearGradient(colors: [Color(white: 0.13), Color(white: 0.075)], startPoint: .top, endPoint: .bottom))
            .overlay(shape.fill(RadialGradient(colors: [Self.warmLight.opacity(0.06), .clear], center: .topLeading,
                                               startRadius: 0, endRadius: 260)))
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.03)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }
}
