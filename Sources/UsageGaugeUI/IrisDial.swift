import SwiftUI

/// Dial drawn like an iris: fine radial strands round a dark pupil, one thin ring at the edge.
/// The remaining share is lit — the tool's colour, with a white strand leading at the head — and
/// the rest stays a quiet faint white. Only the head moves: its strand breathes and the strands
/// just behind it shimmer. The pupil's rim doubles as a clock: it brightens from 12 o'clock as
/// the window runs, with a dot at the current moment, and is full at the reset.
public struct IrisDial: View {
    let remainingPercent: Double
    let elapsedFraction: Double?
    let color: Color
    let frozenAt: TimeInterval?

    private static let frameInterval: TimeInterval = 1.0 / 12
    /// Strands per point of radius, so a small dial stays clear instead of crowded.
    private static let strandsPerPoint = 1.6
    private static let pupilRatio = 0.6
    private static let pupilOpacity = 0.5
    private static let strandStart = 1.09
    private static let strandReach = 0.3...0.84
    private static let headReach = 0.96
    /// Every strand leans a little the same way, like the blades of an aperture.
    private static let strandLean = 0.025
    private static let ringRadius = 0.965
    private static let strandWidth = 0.8
    private static let hairline = 0.8
    private static let ringWidth = 0.6
    private static let headStrands = 5
    private static let breathCycle = 3.2

    /// Per-strand length as a share of the strand span, computed once: frames only advance time,
    /// never re-roll shapes. Two slow waves with a little noise on top, so neighbours stay related.
    private static let reaches: [Double] = (0..<300).map { index in
        let share = Double(index) / 300 * 2 * .pi
        let wave = 0.5 + 0.25 * sin(share * 5 + 1) + 0.25 * sin(share * 11 + 4)
        let length = 0.6 * wave + 0.4 * noise(Double(index))
        return strandReach.lowerBound + (strandReach.upperBound - strandReach.lowerBound) * length
    }

    /// - Parameters:
    ///   - elapsedFraction: 0...1, how much of the window has passed; nil hides the rim clock.
    ///   - frozenAt: fixed animation time for still renders; nil animates.
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
        let pupil = outer * Self.pupilRatio

        canvas.fill(circle(center, pupil), with: .color(.black.opacity(Self.pupilOpacity)))
        drawStrands(in: canvas, center: center, pupil: pupil, outer: outer, time: time)
        drawRing(in: canvas, center: center, radius: outer * Self.ringRadius)
        drawRimClock(in: canvas, center: center, radius: pupil * 0.96)
    }

    /// Strands are grouped into two paths, so a frame is a few strokes. The strands leading the lit
    /// run are drawn one by one: white at the head, easing back into the tool's colour.
    private func drawStrands(in canvas: GraphicsContext, center: CGPoint, pupil: Double, outer: Double, time: Double) {
        let count = min(Self.reaches.count, Int(outer * Self.strandsPerPoint))
        let span = outer * 0.9 - pupil
        let litCount = Int((remainingPercent / 100 * Double(count)).rounded())
        let breath = 0.5 + 0.5 * sin(time * 2 * .pi / Self.breathCycle)

        func strand(_ index: Int, reach: Double) -> Path {
            let angle = Double(index) / Double(count) * 2 * .pi - .pi / 2
            var path = Path()
            path.move(to: point(center, pupil * Self.strandStart, angle))
            path.addLine(to: point(center, pupil * Self.strandStart + span * reach, angle + Self.strandLean))
            return path
        }

        var dim = Path(), lit = Path()
        for index in 0..<count {
            if index >= litCount { dim.addPath(strand(index, reach: Self.reaches[index])) }
            else if index < litCount - Self.headStrands { lit.addPath(strand(index, reach: Self.reaches[index])) }
        }
        canvas.stroke(dim, with: .color(.white.opacity(0.13)), lineWidth: Self.strandWidth)
        canvas.stroke(lit, with: .color(color), lineWidth: Self.strandWidth)

        for step in 0..<min(Self.headStrands, litCount) {
            let index = litCount - 1 - step
            let path = strand(index, reach: step == 0 ? Self.headReach - 0.06 * (1 - breath) : Self.reaches[index])
            canvas.stroke(path, with: .color(color), lineWidth: Self.strandWidth)
            let shimmer = 0.5 + 0.5 * sin(time * 2 * .pi / Self.breathCycle - Double(step) * 0.9)
            let whiteness = step == 0 ? 1 : (1 - Double(step) / Double(Self.headStrands)) * (0.3 + 0.4 * shimmer)
            canvas.stroke(path, with: .color(.white.opacity(whiteness)), lineWidth: Self.strandWidth)
        }
    }

    /// One thin ring at the edge: the remaining share in the tool's colour, the rest faint.
    private func drawRing(in canvas: GraphicsContext, center: CGPoint, radius: Double) {
        canvas.stroke(circle(center, radius), with: .color(.white.opacity(0.08)), lineWidth: Self.ringWidth)
        guard remainingPercent > 0 else { return }
        var lit = Path()
        lit.addArc(center: center, radius: radius, startAngle: .degrees(-90),
                   endAngle: .degrees(-90 + 360 * remainingPercent / 100), clockwise: false)
        canvas.stroke(lit, with: .color(color.opacity(0.75)), lineWidth: Self.ringWidth)
    }

    /// The pupil's rim as a clock: faint all round, bright from 12 o'clock to now, dot at now.
    private func drawRimClock(in canvas: GraphicsContext, center: CGPoint, radius: Double) {
        canvas.stroke(circle(center, radius), with: .color(.white.opacity(0.1)), lineWidth: Self.hairline)
        guard let elapsedFraction else { return }
        var passed = Path()
        passed.addArc(center: center, radius: radius, startAngle: .degrees(-90),
                      endAngle: .degrees(-90 + 360 * elapsedFraction), clockwise: false)
        canvas.stroke(passed, with: .color(.white.opacity(0.45)), lineWidth: Self.hairline)
        canvas.fill(circle(point(center, radius, elapsedFraction * 2 * .pi - .pi / 2), 1.7), with: .color(.white))
    }

    /// Deterministic 0..<1 value for a seed, so shapes stay put from frame to frame.
    private static func noise(_ seed: Double) -> Double {
        let value = sin(seed * 12.9898 + 78.233) * 43758.5453
        return value - value.rounded(.down)
    }

    private func point(_ center: CGPoint, _ radius: Double, _ angle: Double) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    private func circle(_ center: CGPoint, _ radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
