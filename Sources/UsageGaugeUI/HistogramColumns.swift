import SwiftUI

/// A row of vertical columns, one per slice of the window, each as tall as what was used in it
/// relative to the tallest. Past slices are white, the current one takes the tool's colour and
/// slices still to come (or without any use) are faint baseline marks. Drawn as soft bars (iris),
/// dotted columns (dot) or stacked thin segments (mono).
struct HistogramColumns: View {
    static let height: CGFloat = 44

    private static let dotPitch: CGFloat = 3.6
    private static let dotSize: CGFloat = 2.4
    private static let dotsAcross = 2
    private static let segmentPitch: CGFloat = 3.2
    private static let segmentHeight: CGFloat = 1.4
    private static let softWidthShare: CGFloat = 0.52
    private static let baselineHeight: CGFloat = 2
    private static let pastOpacity = 0.88
    private static let baselineOpacity = 0.16

    /// % used per slice; nil for slices after now.
    let values: [Double?]
    let tint: Color

    @Environment(\.panelStyle) private var style

    var body: some View {
        Canvas { canvas, size in
            let pitch = size.width / CGFloat(max(values.count, 1))
            let peak = values.compactMap { $0 }.max() ?? 0
            let current = values.lastIndex { $0 != nil }
            var past = Path(), now = Path(), baseline = Path(), nowBaseline = Path(), glow = Path()
            for (index, value) in values.enumerated() {
                let isCurrent = index == current
                let fraction = peak > 0 ? (value ?? 0) / peak : 0
                let isMark = fraction <= 0
                let rect = columnRect(index: index, pitch: pitch, in: size)
                var shape = Path()
                if style == .iris {
                    shape.addRoundedRect(in: barRect(rect, fraction: fraction, isMark: isMark), cornerSize: CGSize(width: rect.width / 2, height: rect.width / 2))
                    if isCurrent && !isMark {
                        glow.addEllipse(in: CGRect(x: rect.midX - 5, y: size.height * (1 - fraction) - 5, width: 10, height: 10))
                    }
                } else {
                    addCells(into: &shape, rect: rect, fraction: fraction, isMark: isMark, size: size)
                }
                switch (isMark, isCurrent) {
                case (true, true): nowBaseline.addPath(shape)
                case (true, false): baseline.addPath(shape)
                case (false, true): now.addPath(shape)
                case (false, false): past.addPath(shape)
                }
            }
            if style == .iris { paintSoft(canvas, past: past, now: now, baseline: baseline, nowBaseline: nowBaseline, glow: glow, size: size) }
            else {
                canvas.fill(baseline, with: .color(.white.opacity(Self.baselineOpacity)))
                canvas.fill(past, with: .color(.white.opacity(Self.pastOpacity)))
                canvas.fill(nowBaseline, with: .color(tint.opacity(0.6)))
                canvas.fill(now, with: .color(tint))
            }
        }
        .frame(height: Self.height)
    }

    private func columnRect(index: Int, pitch: CGFloat, in size: CGSize) -> CGRect {
        let width: CGFloat
        switch style {
        case .iris: width = pitch * Self.softWidthShare
        case .dot: width = Self.dotPitch * CGFloat(Self.dotsAcross - 1) + Self.dotSize
        case .mono: width = pitch * Self.softWidthShare
        }
        return CGRect(x: CGFloat(index) * pitch + (pitch - width) / 2, y: 0, width: width, height: size.height)
    }

    private func barRect(_ column: CGRect, fraction: Double, isMark: Bool) -> CGRect {
        let height = isMark ? Self.baselineHeight : max(column.width, column.height * fraction)
        return CGRect(x: column.minX, y: column.maxY - height, width: column.width, height: height)
    }

    /// Fills the dots or segments of one column from the bottom up; a mark is the bottom cell alone.
    private func addCells(into path: inout Path, rect: CGRect, fraction: Double, isMark: Bool, size: CGSize) {
        let pitch = style == .dot ? Self.dotPitch : Self.segmentPitch
        let rows = Int(size.height / pitch)
        let lit = isMark ? 1 : max(1, Int((fraction * Double(rows)).rounded()))
        for row in 0..<lit {
            let y = size.height - CGFloat(row + 1) * pitch + (pitch - (style == .dot ? Self.dotSize : Self.segmentHeight))
            if style == .dot {
                for across in 0..<Self.dotsAcross {
                    path.addEllipse(in: CGRect(x: rect.minX + CGFloat(across) * Self.dotPitch, y: y, width: Self.dotSize, height: Self.dotSize))
                }
            } else {
                path.addRect(CGRect(x: rect.minX, y: y, width: rect.width, height: Self.segmentHeight))
            }
        }
    }

    private func paintSoft(_ canvas: GraphicsContext, past: Path, now: Path, baseline: Path, nowBaseline: Path, glow: Path, size: CGSize) {
        canvas.fill(baseline, with: .color(.white.opacity(Self.baselineOpacity)))
        canvas.fill(nowBaseline, with: .color(tint.opacity(0.6)))
        let white = Gradient(colors: [.white.opacity(Self.pastOpacity), .white.opacity(0.32)])
        canvas.fill(past, with: .linearGradient(white, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        canvas.drawLayer { layer in
            layer.addFilter(.blur(radius: 4))
            layer.fill(glow, with: .color(tint.opacity(0.9)))
        }
        let lit = Gradient(colors: [tint, tint.opacity(0.4)])
        canvas.fill(now, with: .linearGradient(lit, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
    }
}
