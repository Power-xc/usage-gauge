import SwiftUI

/// A horizontal capsule filled from the left to the remaining share in the tool's colour, the
/// used part faint: dots (dot), upright segments with a brand-coloured last one (mono) or glass
/// holding a luminous liquid with a glowing edge at the fill line (iris).
struct CapsuleBar: View {
    static let height: CGFloat = 22

    private static let dotPitch: CGFloat = 4
    private static let dotRows = 5
    private static let dotSize: CGFloat = 2.5
    private static let segmentPitch: CGFloat = 4
    private static let segmentWidth: CGFloat = 2
    private static let brandSegments = 2
    private static let inset: CGFloat = 3
    private static let dim = Color.white.opacity(0.13)

    let remainingPercent: Double
    let tint: Color

    @Environment(\.panelStyle) private var style

    var body: some View {
        Canvas { canvas, size in
            switch style {
            case .dot: drawDots(canvas, size)
            case .mono: drawSegments(canvas, size)
            case .iris: drawGlass(canvas, size)
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

    private func drawGlass(_ canvas: GraphicsContext, _ size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
        let glass = stadium(bounds)
        canvas.fill(glass, with: .color(.white.opacity(0.06)))
        let liquidBounds = bounds.insetBy(dx: Self.inset, dy: Self.inset)
        let edge = liquidBounds.minX + liquidBounds.width * share
        if share > 0 {
            var liquid = canvas
            liquid.clip(to: stadium(liquidBounds))
            liquid.clip(to: Path(CGRect(x: 0, y: 0, width: edge, height: size.height)))
            liquid.fill(Path(liquidBounds), with: .linearGradient(
                Gradient(stops: [.init(color: tint.opacity(0.35), location: 0), .init(color: tint.opacity(0.75), location: 0.7),
                                 .init(color: tint, location: 1)]),
                startPoint: CGPoint(x: liquidBounds.minX, y: 0), endPoint: CGPoint(x: max(edge, liquidBounds.minX + 1), y: 0)))
            liquid.fill(Path(CGRect(x: liquidBounds.minX, y: liquidBounds.minY, width: liquidBounds.width, height: liquidBounds.height * 0.4)),
                        with: .linearGradient(Gradient(colors: [.white.opacity(0.32), .white.opacity(0)]),
                                              startPoint: CGPoint(x: 0, y: liquidBounds.minY), endPoint: CGPoint(x: 0, y: liquidBounds.midY)))
            var glow = canvas
            glow.clip(to: stadium(liquidBounds))
            glow.drawLayer { layer in
                layer.addFilter(.blur(radius: 3))
                layer.fill(Path(CGRect(x: edge - 2, y: liquidBounds.minY, width: 3, height: liquidBounds.height)),
                           with: .color(.white.opacity(0.9)))
            }
        }
        canvas.stroke(glass, with: .linearGradient(Gradient(colors: [.white.opacity(0.4), .white.opacity(0.08), .white.opacity(0.2)]),
                                                   startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)),
                      lineWidth: 0.8)
    }
}
