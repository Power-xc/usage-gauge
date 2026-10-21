import SwiftUI
import UsageGaugeUI

/// Flat stage in GitHub's dark page colour, so renders sit on the README the way the panel sits on
/// a desktop. Flat also keeps the animated GIF free of gradient banding.
struct Backdrop: View {
    static let color = Color(red: 13 / 255, green: 17 / 255, blue: 23 / 255)

    var body: some View {
        Self.color
    }
}

/// Off-screen stand-in for system glass: smoked fill under a crisp slab edge.
struct RenderedGlass: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.panelCornerRadius, style: .continuous)
        content
            .background(shape.fill(Theme.smoke.opacity(0.72)))
            .overlay(GlassSlabEdge(shape: shape))
            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }
}
