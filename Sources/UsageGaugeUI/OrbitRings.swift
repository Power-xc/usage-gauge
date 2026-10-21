import SwiftUI

/// One ring of the orbit chart: the short window's remaining share in the tool's colour, or nil
/// for a tool that reports nothing (an empty track).
struct OrbitRing {
    let remainingPercent: Double?
    let tint: Color
}

/// Concentric rings, the first outermost, each lit clockwise from 12 o'clock: rings of dots (dot),
/// of thin radial ticks (mono) or solid arcs over faint tracks (iris). A white head marks the
/// end of every lit arc.
struct OrbitRings: View {
    /// Room kept free in the middle for the figure.
    private static let minInnerRadius: CGFloat = 36
    private static let maxPitch: CGFloat = 8.5
    private static let edgeInset: CGFloat = 3
    private static let dotSpacing: CGFloat = 4.4
    private static let tickSpacing: CGFloat = 3.1
    private static let dim = Color.white.opacity(0.13)

    let rings: [OrbitRing]

    @Environment(\.panelStyle) private var style

    /// Radius of the space left free in the middle.
    static func innerRadius(ringCount: Int, size: CGFloat) -> CGFloat {
        size / 2 - edgeInset - pitch(ringCount: ringCount, size: size) * CGFloat(ringCount)
    }

    private static func pitch(ringCount: Int, size: CGFloat) -> CGFloat {
        min(maxPitch, (size / 2 - edgeInset - minInnerRadius) / CGFloat(max(ringCount, 1)))
    }

    var body: some View {
        Canvas { canvas, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let pitch = Self.pitch(ringCount: rings.count, size: size.width)
            for (index, ring) in rings.enumerated() {
                let radius = size.width / 2 - Self.edgeInset - pitch * (CGFloat(index) + 0.5)
                let share = (ring.remainingPercent ?? 0) / 100
                switch style {
                case .dot: drawDots(canvas, center, radius, pitch: pitch, ring: ring, share: share)
                case .mono: drawTicks(canvas, center, radius, pitch: pitch, ring: ring, share: share)
                case .iris: drawArc(canvas, center, radius, pitch: pitch, ring: ring, share: share)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func drawDots(_ canvas: GraphicsContext, _ center: CGPoint, _ radius: CGFloat, pitch: CGFloat,
                          ring: OrbitRing, share: Double) {
        let count = max(12, Int(2 * .pi * radius / Self.dotSpacing))
        let lit = Int((share * Double(count)).rounded())
        let dot = min(2.7, pitch * 0.5)
        var dimmed = Path(), tinted = Path(), head = Path()
        for step in 0..<count {
            let size = step == lit - 1 ? dot * 1.7 : dot
            let rect = CGRect(origin: point(center, radius, angle(step, of: count)), size: .zero).insetBy(dx: -size / 2, dy: -size / 2)
            if step >= lit { dimmed.addEllipse(in: rect) } else if step == lit - 1 { head.addEllipse(in: rect) } else { tinted.addEllipse(in: rect) }
        }
        canvas.fill(dimmed, with: .color(Self.dim))
        canvas.fill(tinted, with: .color(ring.tint))
        canvas.fill(head, with: .color(.white))
    }

    private func drawTicks(_ canvas: GraphicsContext, _ center: CGPoint, _ radius: CGFloat, pitch: CGFloat,
                           ring: OrbitRing, share: Double) {
        let count = max(24, Int(2 * .pi * radius / Self.tickSpacing))
        let lit = Int((share * Double(count)).rounded())
        let length = min(8, pitch * 0.75)
        var dimmed = Path(), tinted = Path(), head = Path()
        for step in 0..<count {
            let tilt = angle(step, of: count)
            let reach = step == lit - 1 ? length * 1.35 : length
            var tick = Path()
            tick.move(to: point(center, radius - length / 2, tilt))
            tick.addLine(to: point(center, radius - length / 2 + reach, tilt))
            if step >= lit { dimmed.addPath(tick) } else if step == lit - 1 { head.addPath(tick) } else { tinted.addPath(tick) }
        }
        let stroke = StrokeStyle(lineWidth: 1.3, lineCap: .butt)
        canvas.stroke(dimmed, with: .color(Self.dim), style: stroke)
        canvas.stroke(tinted, with: .color(ring.tint), style: stroke)
        canvas.stroke(head, with: .color(.white), style: StrokeStyle(lineWidth: 1.9, lineCap: .butt))
    }

    private func drawArc(_ canvas: GraphicsContext, _ center: CGPoint, _ radius: CGFloat, pitch: CGFloat,
                         ring: OrbitRing, share: Double) {
        let width = min(3.2, pitch * 0.5)
        canvas.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                      with: .color(.white.opacity(0.09)), lineWidth: width)
        guard share > 0 else { return }
        let end = -90 + 360 * share
        var arc = Path()
        arc.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(end), clockwise: false)
        canvas.stroke(arc, with: .color(ring.tint), style: StrokeStyle(lineWidth: width, lineCap: .round))
        let tip = point(center, radius, end * .pi / 180)
        let head = width * 0.55
        canvas.fill(Path(ellipseIn: CGRect(x: tip.x - head, y: tip.y - head, width: head * 2, height: head * 2)), with: .color(.white))
    }

    private func angle(_ step: Int, of count: Int) -> Double {
        Double(step) / Double(count) * 2 * .pi - .pi / 2
    }

    private func point(_ center: CGPoint, _ radius: Double, _ angle: Double) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}
