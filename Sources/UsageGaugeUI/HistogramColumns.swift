import SwiftUI

/// A row of vertical columns, one per slice of the window, evenly pitched across the cell and each
/// as tall as what was used in it relative to the tallest. Past slices are white, the current one
/// takes the tool's colour, a faint divider marks now and slices still to come are faint baseline
/// marks. Drawn as soft bars (iris), dotted columns on one lattice (dot) or stacked thin segments
/// (mono).
struct HistogramColumns: View, Animatable {
    static let height: CGFloat = 44

    private static let dotsAcross = 2
    private static let dotShare: CGFloat = 0.72
    private static let segmentPitch: CGFloat = 3.2
    private static let segmentHeight: CGFloat = 1.4
    private static let softWidthShare: CGFloat = 0.5
    private static let baselineHeight: CGFloat = 2
    private static let pastOpacity = 0.88
    private static let idleOpacity = 0.4
    private static let futureOpacity = 0.14
    private static let dividerOpacity = 0.16

    /// % used per slice; nil for slices after now.
    var values: [Double?]
    let tint: Color

    @Environment(\.panelStyle) private var style

    var animatableData: SliceValues {
        get { SliceValues(values) }
        set { values = newValue.slices }
    }

    private enum Kind { case past, current, idlePast, idleCurrent, future }

    var body: some View {
        Canvas { canvas, size in
            let pitch = size.width / CGFloat(max(values.count, 1))
            let peak = values.compactMap { $0 }.max() ?? 0
            let current = values.lastIndex { $0 != nil }
            var paths: [Kind: Path] = [:]
            var glow = Path()
            for (index, value) in values.enumerated() {
                let fraction = peak > 0 ? (value ?? 0) / peak : 0
                let isIdle = fraction <= 0
                let kind: Kind = value == nil ? .future : index == current ? (isIdle ? .idleCurrent : .current) : (isIdle ? .idlePast : .past)
                let column = columnRect(index: index, pitch: pitch, in: size)
                if style == .iris {
                    let height = isIdle ? Self.baselineHeight : max(column.width, column.height * fraction)
                    let bar = CGRect(x: column.minX, y: column.maxY - height, width: column.width, height: height)
                    paths[kind, default: Path()].addRoundedRect(in: bar, cornerSize: CGSize(width: column.width / 2, height: column.width / 2))
                    if kind == .current { glow.addEllipse(in: CGRect(x: bar.midX - 5, y: bar.minY - 5, width: 10, height: 10)) }
                } else {
                    addCells(into: &paths[kind, default: Path()], column: column, fraction: fraction, isIdle: isIdle, pitch: pitch, size: size)
                }
            }
            if let current { drawDivider(canvas, x: CGFloat(current + 1) * pitch, size: size, pitch: pitch) }
            paint(canvas, paths, glow: glow, size: size)
        }
        .frame(height: Self.height)
    }

    // MARK: Geometry

    private func dotPitch(_ pitch: CGFloat) -> CGFloat { pitch / CGFloat(Self.dotsAcross + 1) }

    private func columnRect(index: Int, pitch: CGFloat, in size: CGSize) -> CGRect {
        let width: CGFloat
        switch style {
        case .dot: width = dotPitch(pitch) * (CGFloat(Self.dotsAcross - 1) + Self.dotShare)
        case .iris, .mono: width = pitch * Self.softWidthShare
        }
        return CGRect(x: CGFloat(index) * pitch + (pitch - width) / 2, y: 0, width: width, height: size.height)
    }

    /// Fills the dots or segments of one column from the bottom up; an idle slice is the bottom cell alone.
    private func addCells(into path: inout Path, column: CGRect, fraction: Double, isIdle: Bool, pitch: CGFloat, size: CGSize) {
        let step = style == .dot ? dotPitch(pitch) : Self.segmentPitch
        let cell = style == .dot ? step * Self.dotShare : Self.segmentHeight
        let lit = isIdle ? 1 : max(1, Int((fraction * Double(Int(size.height / step))).rounded()))
        for row in 0..<lit {
            let y = size.height - CGFloat(row) * step - cell
            if style == .dot {
                for across in 0..<Self.dotsAcross {
                    path.addEllipse(in: CGRect(x: column.minX + CGFloat(across) * step, y: y, width: cell, height: cell))
                }
            } else {
                path.addRect(CGRect(x: column.minX, y: y, width: column.width, height: cell))
            }
        }
    }

    // MARK: Painting

    /// A faint line (dots in the dot style) between now and the slices to come.
    private func drawDivider(_ canvas: GraphicsContext, x: CGFloat, size: CGSize, pitch: CGFloat) {
        guard x < size.width else { return }
        let color = Color.white.opacity(Self.dividerOpacity)
        if style == .dot {
            let step = dotPitch(pitch) * 2
            for y in stride(from: size.height - step / 2, through: 0, by: -step) {
                canvas.fill(Path(ellipseIn: CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1)), with: .color(color))
            }
        } else {
            canvas.fill(Path(CGRect(x: x.rounded() - 0.5, y: 0, width: 1, height: size.height)), with: .color(color))
        }
    }

    private func paint(_ canvas: GraphicsContext, _ paths: [Kind: Path], glow: Path, size: CGSize) {
        func fill(_ kind: Kind, _ shading: GraphicsContext.Shading) {
            if let path = paths[kind] { canvas.fill(path, with: shading) }
        }
        fill(.future, .color(.white.opacity(Self.futureOpacity)))
        fill(.idlePast, .color(.white.opacity(Self.idleOpacity)))
        fill(.idleCurrent, .color(tint.opacity(0.6)))
        let top = CGPoint.zero, bottom = CGPoint(x: 0, y: size.height)
        if style == .iris {
            fill(.past, .linearGradient(Gradient(colors: [.white.opacity(Self.pastOpacity), .white.opacity(0.32)]), startPoint: top, endPoint: bottom))
            canvas.drawLayer { layer in
                layer.addFilter(.blur(radius: 4))
                layer.fill(glow, with: .color(tint.opacity(0.9)))
            }
            fill(.current, .linearGradient(Gradient(colors: [tint, tint.opacity(0.4)]), startPoint: top, endPoint: bottom))
        } else {
            fill(.past, .color(.white.opacity(Self.pastOpacity)))
            fill(.current, .color(tint))
        }
    }
}
