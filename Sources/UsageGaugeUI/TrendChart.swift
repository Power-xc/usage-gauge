import SwiftUI
import UsageGaugeCore

/// The line chart of one window's remaining share: a smooth curve over its area, with the axis
/// labels at the left, drawn in the panel's style. Iris lights the curve and the area under it,
/// mono draws a crisp 1 px line over hairline rules and dot sets the curve and its area in dots.
/// The right part, after now, stays empty except for the faint projection.
struct TrendChart: View {
    static let height: CGFloat = 76
    /// Room for the "100" labels; the footer under the chart starts at the same x.
    static let axisInset: CGFloat = 24

    let series: TrendSeries?
    let tint: Color

    @Environment(\.panelStyle) private var style

    var body: some View {
        Canvas { canvas, size in
            let frame = CGRect(x: Self.axisInset, y: Self.edgeInset, width: size.width - Self.axisInset - Self.edgeInset,
                               height: size.height - 2 * Self.edgeInset)
            drawAxis(canvas, frame, width: size.width)
            guard let series else { return }
            let curves = series.segments.filter { $0.count > 1 }.map { run in
                MonotoneCurve(thinned(run.map { place($0, in: frame) }))
            }
            switch style {
            case .mono: drawCrisp(canvas, frame, curves: curves, series: series)
            case .iris: drawLuminous(canvas, frame, curves: curves, series: series)
            case .dot: drawDotted(canvas, frame, curves: curves, series: series)
            }
        }
        .frame(height: Self.height)
    }

    private static let edgeInset: CGFloat = 6
    private static let guideLevels: [Double] = [0, 0.5, 1]
    private static let dashPattern: [CGFloat] = [3, 3]
    private static let projectionOpacity = 0.55
    private static let dotPitch: CGFloat = 4
    private static let newestDots = 8
    private static let haloRadius: CGFloat = 10
    /// Readings closer than this on screen are merged, so the curve flows instead of twitching.
    private static let minimumSpacing: CGFloat = 8

    private func place(_ point: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(x: frame.minX + point.x * frame.width, y: frame.maxY - point.y * frame.height)
    }

    private func thinned(_ points: [CGPoint]) -> [CGPoint] {
        guard let first = points.first, let last = points.last else { return points }
        var kept = [first]
        for point in points.dropFirst() where point.x - kept[kept.count - 1].x >= Self.minimumSpacing { kept.append(point) }
        if kept[kept.count - 1].x < last.x {
            if kept.count > 1, last.x - kept[kept.count - 1].x < Self.minimumSpacing / 2 { kept.removeLast() }
            kept.append(last)
        }
        return kept
    }

    private func level(_ fraction: Double, in frame: CGRect) -> CGFloat {
        (frame.maxY - fraction * frame.height).rounded() + 0.5
    }

    // MARK: Shared

    /// "100", "50" and "0" at the left, and the guides they stand for in the mono and dot styles.
    private func drawAxis(_ canvas: GraphicsContext, _ frame: CGRect, width: CGFloat) {
        for fraction in Self.guideLevels {
            let y = level(fraction, in: frame)
            canvas.draw(Text("\(Int(fraction * 100))").font(Theme.figure(8, .regular, style: style)).foregroundStyle(Theme.faintText),
                        at: CGPoint(x: 0, y: y), anchor: .leading)
            let opacity = fraction == 0 ? 0.16 : 0.07
            switch style {
            case .mono:
                canvas.fill(Path(CGRect(x: frame.minX, y: y - 0.5, width: width - frame.minX, height: 1)), with: .color(.white.opacity(opacity)))
            case .iris:
                guard fraction == 0 else { continue }
                canvas.fill(Path(CGRect(x: frame.minX, y: y - 0.3, width: width - frame.minX, height: 0.6)), with: .color(.white.opacity(0.14)))
            case .dot:
                for x in stride(from: frame.minX, through: width, by: Self.dotPitch) {
                    canvas.fill(Path(ellipseIn: CGRect(x: x - 0.6, y: y - 0.6, width: 1.2, height: 1.2)), with: .color(.white.opacity(opacity + 0.05)))
                }
            }
        }
    }

    private func projection(_ series: TrendSeries, _ frame: CGRect) -> (head: CGPoint, end: CGPoint)? {
        series.projection.map { (place(series.head, in: frame), place($0, in: frame)) }
    }

    private func dashedProjection(_ canvas: GraphicsContext, _ series: TrendSeries, _ frame: CGRect, width: CGFloat) {
        guard let (head, end) = projection(series, frame) else { return }
        var line = Path()
        line.move(to: head)
        line.addLine(to: end)
        canvas.stroke(line, with: .color(tint.opacity(Self.projectionOpacity)),
                      style: StrokeStyle(lineWidth: width, lineCap: .round, dash: Self.dashPattern))
    }

    /// Ringed marker of the latest reading.
    private func marker(_ canvas: GraphicsContext, at center: CGPoint, radius: CGFloat = 4) {
        let ring = CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)
        canvas.fill(Path(ellipseIn: ring), with: .color(.black.opacity(0.6)))
        canvas.stroke(Path(ellipseIn: ring), with: .color(tint), lineWidth: 1.4)
        canvas.fill(Path(ellipseIn: CGRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3)), with: .color(tint))
    }

    /// A soft light of the tool's colour around `center`.
    private func halo(_ canvas: GraphicsContext, at center: CGPoint, radius: CGFloat = Self.haloRadius, opacity: Double) {
        canvas.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)),
                    with: .radialGradient(Gradient(colors: [tint.opacity(opacity), .clear]), center: center, startRadius: 0, endRadius: radius))
    }

    // MARK: Mono

    private func drawCrisp(_ canvas: GraphicsContext, _ frame: CGRect, curves: [MonotoneCurve], series: TrendSeries) {
        for curve in curves {
            canvas.fill(curve.area(down: frame.maxY), with: .color(tint.opacity(0.07)))
            canvas.stroke(curve.path, with: .color(tint), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        }
        if let start = curves.first?.start {
            canvas.fill(Path(CGRect(x: start.x - 2, y: start.y - 2, width: 4, height: 4)), with: .color(tint))
        }
        dashedProjection(canvas, series, frame, width: 1)
        marker(canvas, at: place(series.head, in: frame))
    }

    // MARK: Iris

    private func drawLuminous(_ canvas: GraphicsContext, _ frame: CGRect, curves: [MonotoneCurve], series: TrendSeries) {
        let fade = Gradient(colors: [tint.opacity(0.46), tint.opacity(0.14), tint.opacity(0)])
        for curve in curves {
            canvas.fill(curve.area(down: frame.maxY), with: .linearGradient(
                fade, startPoint: CGPoint(x: 0, y: frame.minY), endPoint: CGPoint(x: 0, y: frame.maxY)))
            canvas.drawLayer { layer in
                layer.addFilter(.blur(radius: 4))
                layer.stroke(curve.path, with: .color(tint), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            canvas.stroke(curve.path, with: .color(tint), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            canvas.stroke(curve.path, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round, lineJoin: .round))
        }
        dashedProjection(canvas, series, frame, width: 1.2)
        if let start = curves.first?.start {
            halo(canvas, at: start, opacity: 0.9)
            canvas.fill(Path(ellipseIn: CGRect(x: start.x - 2.5, y: start.y - 2.5, width: 5, height: 5)), with: .color(.white))
        }
        let head = place(series.head, in: frame)
        halo(canvas, at: head, opacity: 0.6)
        marker(canvas, at: head)
    }

    // MARK: Dot

    private func drawDotted(_ canvas: GraphicsContext, _ frame: CGRect, curves: [MonotoneCurve], series: TrendSeries) {
        func dot(_ center: CGPoint, radius: CGFloat, _ color: Color) {
            canvas.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)), with: .color(color))
        }
        for curve in curves {
            fillDots(canvas, under: curve, frame: frame)
        }
        if let (head, end) = projection(series, frame) {
            let length = hypot(end.x - head.x, end.y - head.y)
            let steps = Int(length / (2 * Self.dotPitch))
            for step in stride(from: 1, through: steps, by: 1) {
                let t = CGFloat(step) / CGFloat(max(steps, 1))
                dot(CGPoint(x: head.x + (end.x - head.x) * t, y: head.y + (end.y - head.y) * t), radius: 1, tint.opacity(Self.projectionOpacity))
            }
        }
        let plotted = curves.flatMap { $0.evenlySpaced(Self.dotPitch) }
        for (index, point) in plotted.enumerated() {
            let isNewest = index >= plotted.count - Self.newestDots
            dot(point, radius: 1.25, isNewest ? tint : .white.opacity(0.9))
        }
        let head = place(series.head, in: frame)
        marker(canvas, at: head, radius: 5.5)
    }

    /// The area under a curve as faint dots on a lattice, thinning out towards the bottom.
    private func fillDots(_ canvas: GraphicsContext, under curve: MonotoneCurve, frame: CGRect) {
        guard let first = curve.start, let last = curve.end else { return }
        let firstColumn = Int(((first.x - frame.minX) / Self.dotPitch).rounded(.up))
        let lastColumn = Int(((last.x - frame.minX) / Self.dotPitch).rounded(.down))
        guard firstColumn <= lastColumn else { return }
        for column in firstColumn...lastColumn {
            let x = frame.minX + CGFloat(column) * Self.dotPitch
            let top = curve.y(at: x)
            var y = frame.maxY - Self.dotPitch
            while y > top + Self.dotPitch / 2 {
                let depth = (y - top) / frame.height
                canvas.fill(Path(ellipseIn: CGRect(x: x - 0.7, y: y - 0.7, width: 1.4, height: 1.4)),
                            with: .color(tint.opacity(max(0.05, 0.32 - depth * 0.45))))
                y -= Self.dotPitch
            }
        }
    }
}
