import SwiftUI

/// Pill with a glass rim, used for labels.
public struct GlassChip<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.07)))
            .overlay(Capsule().strokeBorder(GlassEdge.gradient, lineWidth: 0.8))
    }
}

/// Thin rim that catches light on the top-left edge, as on frosted glass.
public enum GlassEdge {
    public static let gradient = LinearGradient(colors: [.white.opacity(0.34), .white.opacity(0.06), .white.opacity(0.14)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing)
}
