import SwiftUI

/// The remaining share as an upright column in the style's voice: a luminous gradient with a soft
/// head glow (iris), dots lit from the bottom (dot) or stacked segments (mono). The tool's colour
/// marks the top of what is left.
struct VerticalMeter: View {
    let remainingPercent: Double
    let tint: Color
    let size: CGSize

    @Environment(\.panelStyle) private var style

    private static let dotPitch: CGFloat = 5.6
    private static let dotDiameter: CGFloat = 3.4
    private static let segmentPitch: CGFloat = 5
    private static let segmentHeight: CGFloat = 3
    private static let dimOpacity = 0.14

    init(remainingPercent: Double, tint: Color, size: CGSize) {
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.tint = tint
        self.size = size
    }

    var body: some View {
        Group {
            switch style {
            case .iris: luminous
            case .dot: Canvas { canvas, size in drawDots(in: canvas, size: size) }
            case .mono: Canvas { canvas, size in drawSegments(in: canvas, size: size) }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var luminous: some View {
        let fill = size.height * remainingPercent / 100
        let radius = size.width / 2
        return ZStack(alignment: .bottom) {
            Capsule().fill(Theme.track)
            if fill > 0 {
                Capsule()
                    .fill(LinearGradient(stops: [
                        .init(color: tint.opacity(0.1), location: 0),
                        .init(color: tint.opacity(0.6), location: 0.6),
                        .init(color: tint, location: 0.92),
                        .init(color: .white, location: 1),
                    ], startPoint: .bottom, endPoint: .top))
                    .frame(height: max(fill, size.width))
                    .overlay(alignment: .top) {
                        Ellipse()
                            .fill(RadialGradient(colors: [.white.opacity(0.7), tint.opacity(0.35), tint.opacity(0)],
                                                 center: .center, startRadius: 0, endRadius: radius * 1.9))
                            .frame(width: radius * 4, height: radius * 3)
                            .offset(y: -radius * 0.5)
                            .allowsHitTesting(false)
                    }
            }
        }
    }

    private func drawDots(in canvas: GraphicsContext, size: CGSize) {
        let columns = Int((size.width + Self.dotPitch - Self.dotDiameter) / Self.dotPitch)
        let rows = Int((size.height + Self.dotPitch - Self.dotDiameter) / Self.dotPitch)
        let inset = (size.width - (CGFloat(columns - 1) * Self.dotPitch + Self.dotDiameter)) / 2
        let lit = Int((remainingPercent / 100 * Double(rows)).rounded())
        var dim = Path(), bright = Path(), head = Path()
        for row in 0..<rows {
            let y = size.height - Self.dotDiameter - CGFloat(row) * Self.dotPitch
            for column in 0..<columns {
                let rect = CGRect(x: inset + CGFloat(column) * Self.dotPitch, y: y, width: Self.dotDiameter, height: Self.dotDiameter)
                if row >= lit { dim.addEllipse(in: rect) } else if row == lit - 1 { head.addEllipse(in: rect) } else { bright.addEllipse(in: rect) }
            }
        }
        canvas.fill(dim, with: .color(.white.opacity(Self.dimOpacity)))
        canvas.fill(bright, with: .color(.white.opacity(0.9)))
        canvas.fill(head, with: .color(tint))
    }

    private func drawSegments(in canvas: GraphicsContext, size: CGSize) {
        let count = Int((size.height + Self.segmentPitch - Self.segmentHeight) / Self.segmentPitch)
        let lit = Int((remainingPercent / 100 * Double(count)).rounded())
        var dim = Path(), bright = Path(), head = Path()
        for index in 0..<count {
            let rect = CGRect(x: 0, y: size.height - Self.segmentHeight - CGFloat(index) * Self.segmentPitch,
                              width: size.width, height: Self.segmentHeight)
            if index >= lit { dim.addRect(rect) } else if index == lit - 1 { head.addRect(rect) } else { bright.addRect(rect) }
        }
        canvas.fill(dim, with: .color(.white.opacity(Self.dimOpacity)))
        canvas.fill(bright, with: .color(.white.opacity(0.92)))
        canvas.fill(head, with: .color(tint))
    }
}
