import SwiftUI

/// Dial drawn like an iris: a woven band of dots round a dark pupil, radial strands with soft
/// prism-coloured rays, grain, and rings of dots at the edge. The remaining share is lit —
/// white, the tool's colour and the prism tints — the rest stays dim. Strands breathe at their
/// own pace and the band ripples. The pupil's rim doubles as a clock: it brightens from 12
/// o'clock as the window runs, with a dot at the current moment, and is full at the reset.
public struct IrisDial: View {
    let remainingPercent: Double
    let elapsedFraction: Double?
    let color: Color
    let frozenAt: TimeInterval?

    private static let frameInterval: TimeInterval = 1.0 / 12
    /// Densities per point of radius, so a small dial stays clear instead of crowded.
    private static let fibresPerPoint = 2.8
    private static let grainPerPoint = 2.2
    private static let meshDotsPerPoint = 1.3
    private static let pupilRatio = 0.6
    private static let meshRings = 2
    private static let edgeRings: [(radius: Double, dots: Int)] = [(0.93, 84), (0.985, 116)]
    private static let warmWhite = Color(red: 1.0, green: 0.94, blue: 0.84)
    private static let prism: [Color] = [
        Color(red: 0.55, green: 0.76, blue: 1.0),
        Color(red: 1.0, green: 0.62, blue: 0.78),
        Color(red: 1.0, green: 0.86, blue: 0.56),
    ]

    /// Per-strand randomness, computed once: frames only advance time, never re-roll shapes.
    private struct Strand {
        let jitter: Double, reach: Double, inset: Double, bend: Double, rate: Double, phase: Double
    }

    private struct Speck {
        let share: Double, depth: Double, flicker: Double
    }

    private static let strands: [Strand] = (0..<420).map { index in
        let seed = noise(Double(index))
        return Strand(jitter: (seed - 0.5) * 0.02, reach: 0.4 + 0.45 * seed, inset: 0.04 * noise(seed * 91),
                      bend: (noise(seed * 17) - 0.5) * 0.12, rate: 0.6 + seed * 0.9, phase: seed * 40)
    }
    private static let specks: [Speck] = (0..<900).map { index in
        let seed = noise(Double(index) * 3.7)
        let depth = noise(seed * 29)
        return Speck(share: noise(Double(index) * 1.3), depth: 0.15 + 0.7 * depth * depth, flicker: seed * 13)
    }
    private static let rays: [(share: Double, rate: Double, phase: Double)] = (0..<48).map { index in
        let seed = noise(Double(index) * 7.3)
        return ((Double(index) + noise(Double(index) * 5.1)) / 48, 0.5 + seed, seed * 30)
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
        let litShare = remainingPercent / 100

        canvas.fill(circle(center, outer), with: .radialGradient(
            Gradient(stops: [
                .init(color: .black.opacity(0.6), location: 0),
                .init(color: .black.opacity(0.5), location: Self.pupilRatio * 0.95),
                .init(color: .black.opacity(0), location: 1),
            ]), center: center, startRadius: 0, endRadius: outer))
        drawGrain(in: canvas, center: center, pupil: pupil, outer: outer, litShare: litShare, time: time)
        drawRays(in: canvas, center: center, outer: outer, litShare: litShare, time: time)
        drawStrands(in: canvas, center: center, pupil: pupil, outer: outer, litShare: litShare, time: time)
        drawMesh(in: canvas, center: center, pupil: pupil, outer: outer, litShare: litShare, time: time)
        drawEdgeRings(in: canvas, center: center, outer: outer, litShare: litShare)
        drawRimClock(in: canvas, center: center, radius: pupil * 0.96)
    }

    /// Strands are grouped into a few paths by shade, so a frame is a handful of strokes. They are
    /// fine and many, each fading in from the pupil and out towards the rim over a faint pool of the
    /// tool's colour, so the lit share reads as silk rather than drawn lines.
    private func drawStrands(in canvas: GraphicsContext, center: CGPoint, pupil: Double, outer: Double,
                             litShare: Double, time: Double) {
        var dim = Path(), bright = Path(), tinted = Path(), soft = Path()
        let count = min(Self.strands.count, Int(outer * Self.fibresPerPoint))
        let span = outer * 0.9 - pupil
        for index in 0..<count {
            let strand = Self.strands[index]
            let share = Double(index) / Double(count)
            let angle = share * 2 * .pi - .pi / 2 + strand.jitter
            let breath = 0.5 + 0.5 * sin(time * strand.rate + strand.phase)
            let start = pupil * (1.06 + strand.inset)
            var path = Path()
            path.move(to: point(center, start, angle))
            // A slight sideways drift makes strands read as fibres, not spokes.
            path.addLine(to: point(center, start + span * (strand.reach + 0.15 * breath), angle + strand.bend))
            guard share < litShare else { dim.addPath(path); continue }
            switch index % 4 {
            case 0: bright.addPath(path)
            case 2: soft.addPath(path)
            default: tinted.addPath(path)
            }
        }
        let fade = { (shade: Color, opacity: Double) in
            GraphicsContext.Shading.radialGradient(Gradient(stops: [
                .init(color: shade.opacity(0), location: 0),
                .init(color: shade.opacity(opacity), location: 0.3),
                .init(color: shade.opacity(opacity * 0.55), location: 0.75),
                .init(color: shade.opacity(0), location: 1),
            ]), center: center, startRadius: pupil, endRadius: outer * 0.95)
        }
        if litShare > 0 {
            var pool = Path()
            pool.addArc(center: center, radius: (pupil + outer * 0.9) / 2, startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * litShare), clockwise: false)
            canvas.stroke(pool, with: fade(color, 0.16), style: StrokeStyle(lineWidth: outer * 0.9 - pupil, lineCap: .butt))
        }
        let line = { (width: Double) in StrokeStyle(lineWidth: width, lineCap: .round) }
        canvas.stroke(dim, with: fade(.white, 0.1), style: line(0.5))
        canvas.stroke(soft, with: fade(.white, 0.42), style: line(0.55))
        canvas.stroke(tinted, with: fade(color, 0.9), style: line(0.65))
        canvas.stroke(bright, with: fade(.white, 0.75), style: line(0.55))
    }

    /// Soft rays across the lit share, every other one in the tool's colour and the rest in faint
    /// prism tints, each swelling and fading on its own.
    private func drawRays(in canvas: GraphicsContext, center: CGPoint, outer: Double, litShare: Double, time: Double) {
        var paths = Array(repeating: Path(), count: Self.prism.count * 2)
        for (index, ray) in Self.rays.enumerated() where ray.share < litShare {
            let swell = 0.5 + 0.5 * sin(time * ray.rate + ray.phase)
            let angle = ray.share * 2 * .pi - .pi / 2
            paths[index % paths.count].move(to: point(center, outer * (0.7 - 0.04 * swell), angle))
            paths[index % paths.count].addLine(to: point(center, outer * (0.82 + 0.06 * swell), angle))
        }
        for (index, path) in paths.enumerated() {
            let tint = index.isMultiple(of: 2) ? color.opacity(0.36) : Self.prism[index / 2].opacity(0.2)
            canvas.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
    }

    /// Rings of dots hugging the pupil, rippling slightly so they read as a woven band.
    private func drawMesh(in canvas: GraphicsContext, center: CGPoint, pupil: Double, outer: Double,
                          litShare: Double, time: Double) {
        var lit = Path(), dark = Path()
        let dots = Int(outer * Self.meshDotsPerPoint)
        for ring in 0..<Self.meshRings {
            let base = pupil * 1.03 + Double(ring) * outer * 0.05
            for dot in 0..<dots {
                let share = (Double(dot) + Double(ring) * 0.5) / Double(dots)
                let angle = share * 2 * .pi - .pi / 2
                let ripple = outer * 0.012 * sin(angle * 5 + time * 0.8 + Double(ring) * 1.3)
                let spot = point(center, base + ripple, angle)
                let rect = CGRect(x: spot.x - 0.65, y: spot.y - 0.65, width: 1.3, height: 1.3)
                if share < litShare { lit.addEllipse(in: rect) } else { dark.addEllipse(in: rect) }
            }
        }
        canvas.fill(dark, with: .color(.white.opacity(0.14)))
        canvas.fill(lit, with: .color(.white.opacity(0.6)))
    }

    /// Two rings of dots at the rim, lit warm white inside and in the tool's colour outside.
    private func drawEdgeRings(in canvas: GraphicsContext, center: CGPoint, outer: Double, litShare: Double) {
        var dark = Path()
        for (index, ring) in Self.edgeRings.enumerated() {
            var lit = Path()
            for dot in 0..<ring.dots {
                let share = Double(dot) / Double(ring.dots)
                let spot = point(center, outer * ring.radius, share * 2 * .pi - .pi / 2)
                let rect = CGRect(x: spot.x - 0.75, y: spot.y - 0.75, width: 1.5, height: 1.5)
                if share < litShare { lit.addEllipse(in: rect) } else { dark.addEllipse(in: rect) }
            }
            let isOuter = index == Self.edgeRings.count - 1
            canvas.fill(lit, with: .color(isOuter ? color.opacity(0.8) : Self.warmWhite.opacity(0.55)))
        }
        canvas.fill(dark, with: .color(.white.opacity(0.14)))
    }

    /// Stippled grain, densest mid-ring, shimmering as each speck fades in and out.
    private func drawGrain(in canvas: GraphicsContext, center: CGPoint, pupil: Double, outer: Double,
                           litShare: Double, time: Double) {
        var lit = Path(), dark = Path()
        let flicker = Double(Int(time * 6) % 7)
        let count = min(Self.specks.count, Int(outer * Self.grainPerPoint))
        for speck in Self.specks.prefix(count) where Self.noise(speck.flicker + flicker) > 0.35 {
            let spot = point(center, pupil + (outer - pupil) * speck.depth, speck.share * 2 * .pi - .pi / 2)
            let rect = CGRect(x: spot.x - 0.55, y: spot.y - 0.55, width: 1.1, height: 1.1)
            if speck.share < litShare { lit.addRect(rect) } else { dark.addRect(rect) }
        }
        canvas.fill(dark, with: .color(.white.opacity(0.18)))
        canvas.fill(lit, with: .color(.white.opacity(0.7)))
    }

    /// The pupil's rim as a clock: faint all round, bright from 12 o'clock to now, dot at now.
    private func drawRimClock(in canvas: GraphicsContext, center: CGPoint, radius: Double) {
        canvas.stroke(circle(center, radius), with: .color(.white.opacity(0.07)), lineWidth: 0.8)
        guard let elapsedFraction else { return }
        var passed = Path()
        passed.addArc(center: center, radius: radius, startAngle: .degrees(-90),
                      endAngle: .degrees(-90 + 360 * elapsedFraction), clockwise: false)
        canvas.stroke(passed, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        let dot = point(center, radius, elapsedFraction * 2 * .pi - .pi / 2)
        canvas.fill(circle(dot, 4.5), with: .radialGradient(Gradient(colors: [color.opacity(0.7), color.opacity(0)]),
                                                            center: dot, startRadius: 0, endRadius: 4.5))
        canvas.fill(circle(dot, 1.6), with: .color(.white))
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
