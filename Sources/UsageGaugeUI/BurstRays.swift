import SwiftUI

/// A starburst of one window's use: the period runs clockwise from 12 o'clock like a clock face, a
/// ray per slice as long as what was used in it (relative to the heaviest), ending in a dot. Past
/// rays are white, the current one takes the tool's colour and the time still ahead is a faint arc.
/// The middle is left open for the caller's figure. Drawn as fine solid rays (iris), dotted
/// lines (dot) or hairlines with square ends (mono).
struct BurstRays: View, Animatable {
    static let size: CGFloat = 108
    static let slices = 36
    /// Radius of the open middle, as a share of the half size.
    static let hollowShare: CGFloat = 0.5

    private static let stub: CGFloat = 4
    /// The current ray is never shorter than this, so now stays visible in a quiet slice.
    private static let currentStub: CGFloat = 9
    private static let endMargin: CGFloat = 3
    private static let dotPitch: CGFloat = 3
    private static let pastOpacity = 0.85
    private static let arcOpacity = 0.18
    private static let irisRayOpacity = 0.7

    /// % used per slice; nil for slices after now.
    var values: [Double?]
    let tint: Color

    @Environment(\.panelStyle) private var style

    var animatableData: SliceValues {
        get { SliceValues(values) }
        set { values = newValue.slices }
    }

    var body: some View {
        Canvas { canvas, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let base = size.width / 2 * Self.hollowShare
            let reach = size.width / 2 - base - Self.endMargin
            let peak = values.compactMap { $0 }.max() ?? 0
            let current = values.lastIndex { $0 != nil }
            drawArc(canvas, center: center, radius: base, from: current.map { $0 + 1 } ?? 0)
            for (index, value) in values.enumerated() {
                guard let value else { continue }
                let heaviness = peak > 0 ? value / peak : 0
                let isCurrent = index == current
                let length = Self.stub + (reach - Self.stub) * heaviness
                let ray = Ray(center: center, angle: angle(of: index), base: base,
                              length: isCurrent ? max(length, Self.currentStub) : length, heaviness: heaviness)
                draw(ray, in: canvas, isCurrent: isCurrent)
            }
        }
        .frame(width: Self.size, height: Self.size)
    }

    private struct Ray {
        let center: CGPoint
        let angle: Double
        let base: CGFloat
        let length: CGFloat
        let heaviness: Double

        func point(at radius: CGFloat) -> CGPoint {
            CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        var from: CGPoint { point(at: base) }
        var tip: CGPoint { point(at: base + length) }
    }

    /// Centre of a slice, clockwise from 12 o'clock.
    private func angle(of slice: Int) -> Double {
        -.pi / 2 + (Double(slice) + 0.5) / Double(Self.slices) * 2 * .pi
    }

    private func draw(_ ray: Ray, in canvas: GraphicsContext, isCurrent: Bool) {
        let color: Color = isCurrent ? tint : .white.opacity(Self.pastOpacity)
        switch style {
        case .mono: drawHairline(ray, canvas, color, isCurrent: isCurrent)
        case .dot: drawDotted(ray, canvas, color, isCurrent: isCurrent)
        case .iris: drawSolid(ray, canvas, color, isCurrent: isCurrent)
        }
    }

    private func disc(_ canvas: GraphicsContext, at point: CGPoint, radius: CGFloat, _ color: Color) {
        canvas.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: 2 * radius, height: 2 * radius)),
                    with: .color(color))
    }

    private func line(_ ray: Ray) -> Path {
        var path = Path()
        path.move(to: ray.from)
        path.addLine(to: ray.tip)
        return path
    }

    // MARK: Mono

    private func drawHairline(_ ray: Ray, _ canvas: GraphicsContext, _ color: Color, isCurrent: Bool) {
        canvas.stroke(line(ray), with: .color(color.opacity(0.7)), lineWidth: 0.8)
        let side = 2 + 1.2 * ray.heaviness + (isCurrent ? 0.8 : 0)
        canvas.fill(Path(CGRect(x: ray.tip.x - side / 2, y: ray.tip.y - side / 2, width: side, height: side)), with: .color(color))
    }

    // MARK: Dot

    private func drawDotted(_ ray: Ray, _ canvas: GraphicsContext, _ color: Color, isCurrent: Bool) {
        let steps = Int(ray.length / Self.dotPitch)
        for step in 0..<steps {
            disc(canvas, at: ray.point(at: ray.base + CGFloat(step) * Self.dotPitch), radius: 0.65, color.opacity(0.7))
        }
        disc(canvas, at: ray.tip, radius: 1.3 + 0.9 * ray.heaviness + (isCurrent ? 0.6 : 0), color)
    }

    // MARK: Iris

    private func drawSolid(_ ray: Ray, _ canvas: GraphicsContext, _ color: Color, isCurrent: Bool) {
        canvas.stroke(line(ray), with: .color(color.opacity(isCurrent ? 1 : Self.irisRayOpacity)),
                      style: StrokeStyle(lineWidth: isCurrent ? 1.4 : 0.9, lineCap: .round))
        disc(canvas, at: ray.tip, radius: 1.2 + 1.1 * ray.heaviness + (isCurrent ? 0.6 : 0), color)
    }

    // MARK: Arc

    /// The time still ahead: a faint thin arc on the circle the rays start from, from slice
    /// `first` round to 12 o'clock.
    private func drawArc(_ canvas: GraphicsContext, center: CGPoint, radius: CGFloat, from first: Int) {
        guard first < Self.slices else { return }
        let start = Double(first) / Double(Self.slices) * 2 * .pi - .pi / 2
        var arc = Path()
        arc.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(1.5 * .pi),
                   clockwise: false)
        switch style {
        case .mono: canvas.stroke(arc, with: .color(.white.opacity(Self.arcOpacity)), lineWidth: 1)
        case .iris: canvas.stroke(arc, with: .color(.white.opacity(Self.arcOpacity)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        case .dot: canvas.stroke(arc, with: .color(.white.opacity(Self.arcOpacity + 0.1)),
                                 style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [0.1, Self.dotPitch]))
        }
    }
}
