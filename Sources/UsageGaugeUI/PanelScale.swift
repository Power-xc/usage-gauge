import SwiftUI

public extension View {
    /// Draws the view at `scale` times its natural size and reports the scaled size to its parent,
    /// so a window hugging it follows. Scaling is a render transform, so text and Canvas drawings
    /// stay crisp and hit-testing follows what is drawn.
    func panelScale(_ scale: Double) -> some View {
        ScaledLayout(scale: scale) { scaleEffect(scale, anchor: .topLeading) }
    }
}

private struct ScaledLayout: Layout {
    let scale: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        guard let natural = subviews.first?.sizeThatFits(.unspecified) else { return .zero }
        return CGSize(width: natural.width * scale, height: natural.height * scale)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: .unspecified)
    }
}
