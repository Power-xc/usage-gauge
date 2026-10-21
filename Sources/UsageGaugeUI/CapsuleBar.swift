import SwiftUI

/// A horizontal capsule filled from the left to the remaining share in the tool's colour, the
/// used part faint: dots (dot), upright segments with a brand-coloured last one (mono) or a flat
/// pane holding a solid fill that ends in a white dot (iris).
struct CapsuleBar: View {
    static let height: CGFloat = 22

    private static let dotPitch: CGFloat = 4
    private static let dotRows = 5
    private static let dotSize: CGFloat = 2.5
    private static let segmentPitch: CGFloat = 4
    private static let segmentWidth: CGFloat = 2
    private static let brandSegments = 2
    private static let inset: CGFloat = 3
    private static let headShare: CGFloat = 0.4
    private static let dim = Color.white.opacity(0.13)

    let remainingPercent: Double
    let tint: Color

    @Environment(\.panelStyle) private var style

    var body: some View {
        Canvas { canvas, size in
            switch style {
            case .dot: drawDots(canvas, size)
            case .mono: drawSegments(canvas, size)
            case .iris: drawFlat(canvas, size)
            }
        }
        .frame(height: Self.height)
    }

    private var share: Double { min(100, max(0, remainingPercent)) / 100 }

    private func stadium(_ rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: rect.height / 2)
    }

    /// Dots on a grid, kept where they fall inside the capsule; the outermost ring of the grid
    /// is the outline.
    private func drawDots(_ canvas: GraphicsContext, _ size: CGSize) {
        let columns = Int(size.width / Self.dotPitch)
        let span = Self.dotPitch * CGFloat(Self.dotRows - 1)
        let top = (size.height - span - Self.dotSize) / 2
        let radius = span / 2 + Self.dotSize / 2
        let litEdge = share * size.width
        var dimmed = Path(), lit = Path()
        for column in 0..<columns {
            let x = CGFloat(column) * Self.dotPitch
            for row in 0..<Self.dotRows {
                let y = top + CGFloat(row) * Self.dotPitch
                let dx = max(0, radius - x - Self.dotSize / 2, x + Self.dotSize / 2 - (size.width - radius))
                let dy = y + Self.dotSize / 2 - size.height / 2
                guard dx * dx + dy * dy <= radius * radius + 0.5 else { continue }
                let rect = CGRect(x: x, y: y, width: Self.dotSize, height: Self.dotSize)
                if x + Self.dotSize / 2 <= litEdge { lit.addEllipse(in: rect) } else { dimmed.addEllipse(in: rect) }
            }
        }
        canvas.fill(dimmed, with: .color(Self.dim))
        canvas.fill(lit, with: .color(tint))
    }

    private func drawSegments(_ canvas: GraphicsContext, _ size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
        canvas.stroke(stadium(bounds), with: .color(.white.opacity(0.4)), lineWidth: 1)
        let inner = bounds.insetBy(dx: Self.inset + 1, dy: Self.inset + 1)
        let count = Int((inner.width + Self.segmentPitch - Self.segmentWidth) / Self.segmentPitch)
        let lit = Int((share * Double(count)).rounded())
        var dimmed = Path(), body = Path(), head = Path()
        for index in 0..<count {
            let rect = CGRect(x: inner.minX + CGFloat(index) * Self.segmentPitch, y: inner.minY,
                              width: Self.segmentWidth, height: inner.height)
            if index >= lit { dimmed.addRect(rect) } else if index >= lit - Self.brandSegments { head.addRect(rect) } else { body.addRect(rect) }
        }
        canvas.fill(dimmed, with: .color(.white.opacity(0.16)))
        canvas.fill(body, with: .color(.white.opacity(0.92)))
        canvas.fill(head, with: .color(tint))
    }

    private func drawFlat(_ canvas: GraphicsContext, _ size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
        let pane = stadium(bounds)
        canvas.fill(pane, with: .color(.white.opacity(0.06)))
        let inner = bounds.insetBy(dx: Self.inset, dy: Self.inset)
        if share > 0 {
            let width = max(inner.height, inner.width * share)
            canvas.fill(stadium(CGRect(x: inner.minX, y: inner.minY, width: width, height: inner.height)), with: .color(tint))
            let radius = inner.height * Self.headShare / 2
            canvas.fill(Path(ellipseIn: CGRect(x: inner.minX + width - inner.height / 2 - radius, y: inner.midY - radius,
                                               width: radius * 2, height: radius * 2)), with: .color(.white))
        }
        canvas.stroke(pane, with: .color(.white.opacity(0.18)), lineWidth: 0.8)
    }
}
