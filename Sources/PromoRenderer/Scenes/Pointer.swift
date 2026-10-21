import SwiftUI

/// The macOS arrow pointer, drawn as a vector: black body, white rim, tip at the view's origin.
struct ArrowPointer: View {
    private static let outline: [CGPoint] = [
        CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 17), CGPoint(x: 4, y: 13.2), CGPoint(x: 7.2, y: 20),
        CGPoint(x: 9.9, y: 18.8), CGPoint(x: 6.8, y: 12.2), CGPoint(x: 12, y: 12.2),
    ]

    /// How far the arrow is pressed in, 0...1.
    var press = 0.0

    var body: some View {
        let shape = Path { path in
            path.addLines(Self.outline)
            path.closeSubpath()
        }
        ZStack {
            shape.fill(.black)
            shape.stroke(.white, style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
        }
        .scaleEffect(1 - 0.1 * press, anchor: .topLeading)
    }
}

/// The ring that spreads from a click and fades.
struct PressRing: View {
    private static let startDiameter: CGFloat = 6
    private static let endDiameter: CGFloat = 30

    /// 0 at the click, 1 when the ring is gone.
    let age: Double

    var body: some View {
        let spread = Motion.progress(age, from: 0, to: 1)
        let diameter = Self.startDiameter + (Self.endDiameter - Self.startDiameter) * spread
        Circle()
            .strokeBorder(.white.opacity(0.6 * (1 - age)), lineWidth: 1.5)
            .frame(width: diameter, height: diameter)
    }
}
