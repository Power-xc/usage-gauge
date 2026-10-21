import SwiftUI

/// Dial in the terminal style: a ring of radial ticks lit for the remaining share, lengthening
/// towards the leading tick, which carries the tool's colour and breathes. A thin inner circle is
/// the clock: the elapsed part of the window drawn bright from 12 o'clock.
public struct TickDial: View {
    let remainingPercent: Double
    let elapsedFraction: Double?
    let color: Color
    let frozenAt: TimeInterval?

    private static let frameInterval: TimeInterval = 1.0 / 12
    private static let ticksPerPoint = 1.25
    private static let innerRadius = 0.72
    private static let outerRadius = 0.98
    private static let clockRadius = 0.6
    /// How much shorter the oldest lit tick is than the leading one, as in a loading spinner.
    private static let taper = 0.45

    public init(remainingPercent: Double, elapsedFraction: Double?, color: Color, frozenAt: TimeInterval? = nil) {
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.elapsedFraction = elapsedFraction.map { min(1, max(0, $0)) }
        self.color = color
        self.frozenAt = frozenAt
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: Self.frameInterval, paused: frozenAt != nil)) { context in
            let time = frozenAt ?? context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                draw(in: canvas, size: size, time: time.truncatingRemainder(dividingBy: 3600))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func draw(in canvas: GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = min(size.width, size.height) / 2
        let ticks = max(24, Int(outer * Self.ticksPerPoint / 4) * 4)
        let lit = Int((remainingPercent / 100 * Double(ticks)).rounded())
        let width = max(1, outer * 0.035)
        var dim = Path(), bright = Path(), head = Path()
        for tick in 0..<ticks {
            let angle = Double(tick) / Double(ticks) * 2 * .pi - .pi / 2
            let span = Self.outerRadius - Self.innerRadius
            let reach = tick < lit ? 1 - Self.taper * Double(lit - 1 - tick) / Double(max(1, lit)) : 0.55
            var path = Path()
            path.move(to: point(center, outer * Self.innerRadius, angle))
            path.addLine(to: point(center, outer * (Self.innerRadius + span * reach), angle))
            if tick >= lit { dim.addPath(path) } else if tick == lit - 1 { head.addPath(path) } else { bright.addPath(path) }
        }
        let style = StrokeStyle(lineWidth: width, lineCap: .butt)
        canvas.stroke(dim, with: .color(.white.opacity(0.14)), style: style)
        canvas.stroke(bright, with: .color(.white.opacity(0.92)), style: style)
        var breathing = canvas
        breathing.opacity = 0.75 + 0.25 * sin(time * 3)
        breathing.stroke(head, with: .color(color), style: StrokeStyle(lineWidth: width * 1.6, lineCap: .butt))
        drawClock(in: canvas, center: center, radius: outer * Self.clockRadius, width: width)
    }

    private func drawClock(in canvas: GraphicsContext, center: CGPoint, radius: Double, width: Double) {
        canvas.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                      with: .color(.white.opacity(0.16)), lineWidth: width * 0.7)
        guard let elapsedFraction, elapsedFraction > 0 else { return }
        var passed = Path()
        passed.addArc(center: center, radius: radius, startAngle: .degrees(-90),
                      endAngle: .degrees(-90 + 360 * elapsedFraction), clockwise: false)
        canvas.stroke(passed, with: .color(.white.opacity(0.75)), lineWidth: width)
    }

    private func point(_ center: CGPoint, _ radius: Double, _ angle: Double) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}

/// The long window as a row of upright segments: lit for the remaining share, the leading one in
/// the tool's colour.
public struct TickBar: View {
    let remainingPercent: Double
    let color: Color

    private static let pitch: CGFloat = 3.2
    private static let width: CGFloat = 1.4
    private static let height: CGFloat = 9

    public init(remainingPercent: Double, color: Color) {
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.color = color
    }

    public var body: some View {
        Canvas { canvas, size in
            let count = Int((size.width + Self.pitch - Self.width) / Self.pitch)
            let lit = Int((remainingPercent / 100 * Double(count)).rounded())
            var dim = Path(), bright = Path(), head = Path()
            for index in 0..<count {
                let rect = CGRect(x: Double(index) * Self.pitch, y: 0, width: Self.width, height: Self.height)
                if index >= lit { dim.addRect(rect) } else if index == lit - 1 { head.addRect(rect) } else { bright.addRect(rect) }
            }
            canvas.fill(dim, with: .color(.white.opacity(0.16)))
            canvas.fill(bright, with: .color(.white.opacity(0.92)))
            canvas.fill(head, with: .color(color))
        }
        .frame(height: Self.height)
    }
}
