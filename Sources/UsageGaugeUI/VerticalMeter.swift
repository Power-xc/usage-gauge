import SwiftUI

/// The remaining share as an upright column in the style's voice: a solid fill with a white head
/// dot (iris), dots lit from the bottom (dot) or stacked segments (mono). The tool's colour
/// marks the top of what is left.
struct VerticalMeter: View, Animatable {
    var remainingPercent: Double
    let tint: Color
    let size: CGSize

    @Environment(\.panelStyle) private var style

    private static let dotPitch: CGFloat = 5.6
    private static let dotDiameter: CGFloat = 3.4
    private static let segmentPitch: CGFloat = 5
    private static let segmentHeight: CGFloat = 3
    private static let dimOpacity = 0.14
    private static let headShare: CGFloat = 0.4

    init(remainingPercent: Double, tint: Color, size: CGSize) {
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.tint = tint
        self.size = size
    }

    /// The share eases to a new value, so the column grows instead of jumping.
    var animatableData: Double {
        get { remainingPercent }
        set { remainingPercent = min(100, max(0, newValue)) }
    }

    var body: some View {
        Group {
            switch style {
            case .iris: solid
            case .dot: Canvas { canvas, size in drawDots(in: canvas, size: size) }
            case .mono: Canvas { canvas, size in drawSegments(in: canvas, size: size) }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var solid: some View {
        let fill = max(size.height * remainingPercent / 100, size.width)
        return ZStack(alignment: .bottom) {
            Capsule().fill(Theme.track)
            if remainingPercent > 0 {
                Capsule().fill(tint)
                    .frame(height: fill)
                    .overlay(alignment: .top) {
                        Circle().fill(.white).frame(width: size.width * Self.headShare).padding(.top, size.width * (1 - Self.headShare) / 2)
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
