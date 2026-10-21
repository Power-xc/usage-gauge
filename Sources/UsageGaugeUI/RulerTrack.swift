import SwiftUI

/// A vertical ruler from 0 at the bottom to 100 at the top: numbered long ticks every 25, short
/// ticks every 5, and a line in the tool's colour running up to the short window's share. The line
/// bulges outward in a smooth bump around a round knob at that share and fades out above it; the
/// long window is a small notch on the ticks' side. Drawn as a solid line and a flat dark knob with a
/// fine rim (iris), a 1 px line and a hollow knob (mono) or dots and a ring of dots (dot).
struct RulerTrack: View, Animatable {
    /// Where the geometry of the ruler is read by the figure beside it.
    enum Metrics {
        static let spineX: CGFloat = 30
        static let knobRadius: CGFloat = 6.5
        /// How far the line stands off the spine at the knob.
        static let bulge: CGFloat = 11
        /// Room above and below the ruler for the figure that sits at its ends.
        static let endPadding: CGFloat = 16

        /// Height of `share` (0...100) from the top of a ruler `height` points tall.
        static func y(of share: Double, in height: CGFloat) -> CGFloat {
            let span = height - 2 * endPadding
            return endPadding + span * (1 - CGFloat(share / 100))
        }

        /// Where the figure beside the knob starts.
        static let figureX = spineX + bulge + knobRadius
    }

    private static let bumpHalfWidth: CGFloat = 30
    private static let endTaper: CGFloat = 10
    /// The knob sits a little right of the spine, inside the bulge.
    private static let knobShift: CGFloat = 1.5
    private static let longTick: CGFloat = 8
    private static let shortTick: CGFloat = 4
    private static let tickGap: CGFloat = 4
    private static let notchLength: CGFloat = 15
    private static let notchLabelClearance: CGFloat = 8
    private static let dotPitch: CGFloat = 3.8
    private static let faintOpacity = 0.4
    private static let fadeLength: CGFloat = 22

    let tint: Color
    let notchLabel: String?
    /// Whether the line and knob are drawn; off for a tool without a short window.
    let isActive: Bool
    var remaining: Double
    var longRemaining: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(remaining, longRemaining) }
        set { (remaining, longRemaining) = (newValue.first, newValue.second) }
    }

    @Environment(\.panelStyle) private var style

    var body: some View {
        Canvas { canvas, size in
            let spine = Metrics.spineX
            let knobY = Metrics.y(of: remaining, in: size.height)
            let notchY = notchLabel == nil ? nil : Metrics.y(of: longRemaining, in: size.height)
            drawTicks(canvas, height: size.height, skipping: notchY)
            if let notchY { drawNotch(canvas, y: notchY) }
            guard isActive else { return }
            let line = bumpLine(knobY: knobY, top: Metrics.endPadding, bottom: size.height - Metrics.endPadding)
            drawLine(canvas, points: line, knobY: knobY)
            drawKnob(canvas, center: CGPoint(x: spine + Self.knobShift, y: knobY))
        }
    }

    // MARK: Line

    /// The line down the ruler, two points per point of height, pushed right by a raised-cosine
    /// bump centred on the knob.
    private func bumpLine(knobY: CGFloat, top: CGFloat, bottom: CGFloat) -> [CGPoint] {
        stride(from: top, through: bottom, by: 0.5).map { y in
            let u = min(1, abs(y - knobY) / Self.bumpHalfWidth)
            // Back on the spine at the ends, so the line never leaves the ruler there.
            let taper = min(1, (y - top) / Self.endTaper, (bottom - y) / Self.endTaper)
            return CGPoint(x: Metrics.spineX + Metrics.bulge * taper * (1 + cos(.pi * u)) / 2, y: y)
        }
    }

    /// How strongly the line shows at `y`: full up to the knob, fading out above it.
    private func strength(at y: CGFloat, knobY: CGFloat) -> Double {
        let above = max(0, knobY - y - 4)
        return 1 - (1 - Self.faintOpacity) * Double(min(1, above / Self.fadeLength))
    }

    private func drawLine(_ canvas: GraphicsContext, points: [CGPoint], knobY: CGFloat) {
        guard let first = points.first, let last = points.last else { return }
        switch style {
        case .dot:
            drawDots(canvas, points: points, knobY: knobY)
        case .mono:
            var path = Path()
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            let span = max(1, last.y - first.y)
            func location(_ y: CGFloat) -> CGFloat { min(1, max(0, (y - first.y) / span)) }
            let fade = Gradient(stops: [
                .init(color: tint.opacity(Self.faintOpacity), location: location(knobY - 4 - Self.fadeLength)),
                .init(color: tint, location: location(knobY - 4)),
            ])
            canvas.stroke(path, with: .linearGradient(fade, startPoint: first, endPoint: last), lineWidth: 1)
        case .iris:
            // Two solid strokes meeting at the bulge: full below it, faint above.
            let split = points.firstIndex { $0.y >= knobY } ?? points.count - 1
            let stroke = StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
            canvas.stroke(path(of: points[...split]), with: .color(tint.opacity(Self.faintOpacity)), style: stroke)
            canvas.stroke(path(of: points[split...]), with: .color(tint), style: stroke)
        }
    }

    private func path(of points: ArraySlice<CGPoint>) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    /// Dots at an even spacing along the line, as far apart along the bump as on the straight.
    private func drawDots(_ canvas: GraphicsContext, points: [CGPoint], knobY: CGFloat) {
        var travelled: CGFloat = 0
        var next: CGFloat = 0
        var previous = points[0]
        for point in points {
            travelled += hypot(point.x - previous.x, point.y - previous.y)
            previous = point
            guard travelled >= next else { continue }
            next += Self.dotPitch
            if hypot(point.x - (Metrics.spineX + Self.knobShift), point.y - knobY) < Metrics.knobRadius + 2 { continue }
            canvas.fill(Path(ellipseIn: CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2)),
                        with: .color(tint.opacity(strength(at: point.y, knobY: knobY))))
        }
    }

    // MARK: Knob

    private func drawKnob(_ canvas: GraphicsContext, center: CGPoint) {
        let radius = Metrics.knobRadius
        let disc = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        switch style {
        case .mono:
            canvas.fill(Path(ellipseIn: disc), with: .color(.black))
            canvas.stroke(Path(ellipseIn: disc.insetBy(dx: 0.5, dy: 0.5)), with: .color(tint), lineWidth: 1)
        case .iris:
            canvas.fill(Path(ellipseIn: disc), with: .color(Color(white: 0.04).opacity(0.95)))
            canvas.stroke(Path(ellipseIn: disc.insetBy(dx: 0.5, dy: 0.5)), with: .color(.white.opacity(0.6)), lineWidth: 1)
        case .dot:
            let dots = 12
            var ring = Path()
            for index in 0..<dots {
                let angle = Double(index) / Double(dots) * 2 * .pi
                let point = CGPoint(x: center.x + (radius - 0.5) * CGFloat(cos(angle)), y: center.y + (radius - 0.5) * CGFloat(sin(angle)))
                ring.addEllipse(in: CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2))
            }
            canvas.fill(ring, with: .color(tint))
        }
    }

    // MARK: Ticks and notch

    private func drawTicks(_ canvas: GraphicsContext, height: CGFloat, skipping notchY: CGFloat?) {
        let right = Metrics.spineX - Self.tickGap
        var long = Path(), short = Path()
        for share in stride(from: 0, through: 100, by: 5) {
            let isLong = share % 25 == 0
            let y = Metrics.y(of: Double(share), in: height)
            let length = isLong ? Self.longTick : Self.shortTick
            if style == .dot {
                let dots = isLong ? 3 : 1
                for index in 0..<dots {
                    let x = right - CGFloat(index) * 3.6
                    let dot = Path(ellipseIn: CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8))
                    if isLong { long.addPath(dot) } else { short.addPath(dot) }
                }
            } else {
                let snapped = style == .mono ? y.rounded() + 0.5 : y
                var tick = isLong ? long : short
                tick.move(to: CGPoint(x: right - length, y: snapped))
                tick.addLine(to: CGPoint(x: right, y: snapped))
                if isLong { long = tick } else { short = tick }
            }
            if isLong, notchY.map({ abs($0 - y) > Self.notchLabelClearance }) ?? true {
                canvas.draw(Text("\(share)").font(Theme.mono(7, .regular)).foregroundStyle(Theme.faintText),
                            at: CGPoint(x: right - Self.longTick - 4, y: y), anchor: .trailing)
            }
        }
        let weight: CGFloat = style == .iris ? 0.8 : 1
        if style == .dot {
            canvas.fill(short, with: .color(.white.opacity(0.22)))
            canvas.fill(long, with: .color(.white.opacity(0.5)))
        } else {
            canvas.stroke(short, with: .color(.white.opacity(0.2)), lineWidth: weight)
            canvas.stroke(long, with: .color(.white.opacity(0.42)), lineWidth: weight)
        }
    }

    private func drawNotch(_ canvas: GraphicsContext, y: CGFloat) {
        let right = Metrics.spineX - Self.tickGap + 2
        let left = right - Self.notchLength
        switch style {
        case .mono:
            canvas.fill(Path(CGRect(x: left, y: y.rounded() - 0.5, width: Self.notchLength, height: 2)), with: .color(tint))
        case .iris:
            canvas.fill(Path(roundedRect: CGRect(x: left, y: y - 1.1, width: Self.notchLength, height: 2.2), cornerRadius: 1.1),
                        with: .color(tint))
        case .dot:
            var dots = Path()
            for index in 0..<4 {
                dots.addEllipse(in: CGRect(x: right - 1.2 - CGFloat(index) * 4.2, y: y - 1.2, width: 2.4, height: 2.4))
            }
            canvas.fill(dots, with: .color(tint))
        }
        if let notchLabel {
            canvas.draw(Text(notchLabel).font(Theme.label(7.5, .semibold, style: style)).foregroundStyle(tint),
                        at: CGPoint(x: left - 3, y: y), anchor: .trailing)
        }
    }
}
