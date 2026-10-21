import SwiftUI
import UsageGaugeCore

/// The line chart of one window's remaining share, drawn in the panel's style: dot-matrix points,
/// a 1 px polyline over tick gridlines, or a thin luminous line with a soft glow head. The right
/// part, after now, stays empty except for the faint projection.
struct TrendChart: View {
    static let height: CGFloat = 64

    let series: TrendSeries?
    let tint: Color

    @Environment(\.panelStyle) private var style

    var body: some View {
        Canvas { canvas, size in
            let frame = CGRect(origin: .zero, size: size).insetBy(dx: Self.markerRadius, dy: Self.markerRadius)
            switch style {
            case .dot: drawDots(canvas, frame)
            case .mono: drawPolyline(canvas, frame)
            case .iris: drawGlowLine(canvas, frame)
            }
        }
        .frame(height: Self.height)
    }

    private static let markerRadius: CGFloat = 5
    private static let dotPitch: CGFloat = 4
    private static let newestDots = 6
    private static let dashPattern: [CGFloat] = [3, 3]

    private func place(_ point: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(x: frame.minX + point.x * frame.width, y: frame.maxY - point.y * frame.height)
    }

    private func path(_ points: [CGPoint], in frame: CGRect) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            let placed = place(point, in: frame)
            index == 0 ? path.move(to: placed) : path.addLine(to: placed)
        }
        return path
    }

    private func dashedProjection(_ canvas: GraphicsContext, _ frame: CGRect, width: CGFloat) {
        guard let series, let projection = series.projection else { return }
        let line = path([series.head, projection], in: frame)
        canvas.stroke(line, with: .color(tint.opacity(0.55)), style: StrokeStyle(lineWidth: width, lineCap: .round, dash: Self.dashPattern))
    }

    private func marker(_ canvas: GraphicsContext, _ frame: CGRect) {
        guard let series else { return }
        let center = place(series.head, in: frame)
        let ring = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
        canvas.fill(Path(ellipseIn: ring), with: .color(.black.opacity(0.55)))
        canvas.stroke(Path(ellipseIn: ring), with: .color(tint), lineWidth: 1.5)
        canvas.fill(Path(ellipseIn: CGRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3)), with: .color(tint))
    }

    // MARK: Mono

    private func drawPolyline(_ canvas: GraphicsContext, _ frame: CGRect) {
        for fraction in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let y = (frame.maxY - fraction * frame.height).rounded() + 0.5
            canvas.fill(Path(CGRect(x: 0, y: y, width: frame.maxX + Self.markerRadius, height: 1)),
                        with: .color(.white.opacity(fraction == 0 ? 0.16 : 0.07)))
        }
        for quarter in 0...4 {
            let x = (frame.minX + CGFloat(quarter) / 4 * frame.width).rounded()
            canvas.fill(Path(CGRect(x: min(x, frame.maxX), y: frame.maxY, width: 1, height: 4)), with: .color(.white.opacity(0.22)))
        }
        guard let series else { return }
        for segment in series.segments where segment.count > 1 {
            canvas.stroke(path(segment, in: frame), with: .color(tint), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        }
        dashedProjection(canvas, frame, width: 1)
        marker(canvas, frame)
    }

    // MARK: Iris

    private func drawGlowLine(_ canvas: GraphicsContext, _ frame: CGRect) {
        canvas.fill(Path(CGRect(x: 0, y: frame.maxY, width: frame.maxX + Self.markerRadius, height: 0.6)), with: .color(.white.opacity(0.14)))
        guard let series else { return }
        let stroke = StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
        for segment in series.segments where segment.count > 1 {
            var glow = canvas
            glow.addFilter(.blur(radius: 3))
            glow.stroke(path(segment, in: frame), with: .color(tint.opacity(0.8)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            canvas.stroke(path(segment, in: frame), with: .linearGradient(
                Gradient(colors: [tint.opacity(0.35), tint]), startPoint: place(segment[0], in: frame),
                endPoint: place(segment[segment.count - 1], in: frame)), style: stroke)
        }
        dashedProjection(canvas, frame, width: 1.2)
        let head = place(series.head, in: frame)
        canvas.fill(Path(ellipseIn: CGRect(x: head.x - 11, y: head.y - 11, width: 22, height: 22)),
                    with: .radialGradient(Gradient(colors: [tint.opacity(0.55), .clear]), center: head, startRadius: 0, endRadius: 11))
        marker(canvas, frame)
    }

    // MARK: Dot

    private func drawDots(_ canvas: GraphicsContext, _ frame: CGRect) {
        let columns = Int(frame.width / Self.dotPitch)
        let rows = Int(frame.height / Self.dotPitch)
        let radius: CGFloat = 1.1
        func dot(_ column: Int, _ row: Int, _ color: Color, scale: CGFloat = 1) {
            let center = CGPoint(x: frame.minX + CGFloat(column) * Self.dotPitch, y: frame.maxY - CGFloat(row) * Self.dotPitch)
            let r = radius * scale
            canvas.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)), with: .color(color))
        }
        for column in 0...columns {
            for row in 0...rows { dot(column, row, .white.opacity(row == 0 ? 0.16 : 0.06), scale: 0.8) }
        }
        guard let series else { return }
        func row(at y: CGFloat) -> Int { Int((y * CGFloat(rows)).rounded()) }

        if let projection = series.projection {
            let from = Int((series.head.x * CGFloat(columns)).rounded()), to = Int((projection.x * CGFloat(columns)).rounded())
            if to > from + 1 {
                for column in stride(from: from + 2, through: to, by: 2) {
                    let t = CGFloat(column - from) / CGFloat(to - from)
                    dot(column, row(at: series.head.y + (projection.y - series.head.y) * t), tint.opacity(0.55))
                }
            }
        }
        let plotted = series.segments.flatMap { dotColumns(of: $0, columns: columns) }.sorted { $0.column < $1.column }
        let newest = Set(plotted.suffix(Self.newestDots).map(\.column))
        for mark in plotted { dot(mark.column, row(at: mark.y), newest.contains(mark.column) ? tint : .white.opacity(0.9)) }
        let head = place(series.head, in: frame)
        let ring = CGRect(x: head.x - 5.5, y: head.y - 5.5, width: 11, height: 11)
        canvas.fill(Path(ellipseIn: ring), with: .color(.black.opacity(0.7)))
        canvas.stroke(Path(ellipseIn: ring), with: .color(tint), lineWidth: 1.4)
        dot(Int((series.head.x * CGFloat(columns)).rounded()), row(at: series.head.y), tint, scale: 1.3)
    }

    /// The columns of the dot grid a run of points passes through, with the line's height there.
    private func dotColumns(of segment: [CGPoint], columns: Int) -> [(column: Int, y: CGFloat)] {
        guard let first = segment.first else { return [] }
        guard segment.count > 1 else { return [(Int((first.x * CGFloat(columns)).rounded()), first.y)] }
        let lower = Int((first.x * CGFloat(columns)).rounded(.up)), upper = Int((segment[segment.count - 1].x * CGFloat(columns)).rounded(.down))
        guard lower <= upper else { return [] }
        return (lower...upper).map { column in
            let x = CGFloat(column) / CGFloat(columns)
            let index = segment.lastIndex { $0.x <= x } ?? 0
            let a = segment[index], b = segment[min(index + 1, segment.count - 1)]
            let t = b.x > a.x ? (x - a.x) / (b.x - a.x) : 0
            return (column, a.y + (b.y - a.y) * t)
        }
    }
}
