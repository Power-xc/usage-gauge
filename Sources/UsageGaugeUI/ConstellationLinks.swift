import SwiftUI

/// The lines of the constellation: a thin link from each tool to the next in order of short-window
/// share, and a faded trail from each tool back to where it stood an hour ago. Drawn in one Canvas
/// from the tools' coordinates, which animate, so the lines follow the nodes as values change.
/// Iris keeps them solid: white links and trails in the tool's colour, without glow.
struct ConstellationLinks: View, Animatable {
    /// One tool's fixed look; its coordinates come with `animatableData`.
    struct Line {
        let tint: Color
        let hasTrail: Bool
    }

    private static let valuesPerLine = 4
    private static let minimumTrail: CGFloat = 5
    private static let linkOpacity = 0.6
    private static let irisLinkOpacity = 0.3
    private static let dottedLink = StrokeStyle(lineWidth: 1.7, lineCap: .round, dash: [0.01, 4.4])
    private static let dottedTrail = StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [0.01, 3.2])

    let lines: [Line]
    /// Per tool: x, y of the node, then x, y of where it stood an hour ago, in the Canvas's points.
    var coordinates: AnimatableValues

    var animatableData: AnimatableValues {
        get { coordinates }
        set { coordinates = newValue }
    }

    @Environment(\.panelStyle) private var style

    init(lines: [Line], points: [CGPoint], pasts: [CGPoint?]) {
        self.lines = lines
        coordinates = AnimatableValues(zip(points, pasts).flatMap { [$0.x, $0.y, ($1 ?? $0).x, ($1 ?? $0).y] })
    }

    var body: some View {
        Canvas { canvas, _ in
            let nodes = lines.indices.compactMap { node(at: $0) }
            for node in nodes where node.line.hasTrail { drawTrail(canvas, node) }
            let path = nodes.sorted { $0.point.x < $1.point.x }
            for (from, to) in zip(path, path.dropFirst()) { drawLink(canvas, from, to) }
        }
        .allowsHitTesting(false)
    }

    private struct Node {
        let line: Line
        let point: CGPoint
        let past: CGPoint
    }

    private func node(at index: Int) -> Node? {
        let base = index * Self.valuesPerLine
        guard base + Self.valuesPerLine <= coordinates.values.count else { return nil }
        let values = coordinates.values
        return Node(line: lines[index], point: CGPoint(x: values[base], y: values[base + 1]),
                    past: CGPoint(x: values[base + 2], y: values[base + 3]))
    }

    private func drawLink(_ canvas: GraphicsContext, _ from: Node, _ to: Node) {
        var line = Path()
        line.move(to: from.point)
        line.addLine(to: to.point)
        func shading(_ opacity: Double) -> GraphicsContext.Shading {
            .linearGradient(Gradient(colors: [from.line.tint.opacity(opacity), to.line.tint.opacity(opacity)]),
                            startPoint: from.point, endPoint: to.point)
        }
        switch style {
        case .mono:
            canvas.stroke(line, with: shading(Self.linkOpacity), lineWidth: 1)
        case .dot:
            canvas.stroke(line, with: shading(0.8), style: Self.dottedLink)
        case .iris:
            canvas.stroke(line, with: .color(.white.opacity(Self.irisLinkOpacity)), lineWidth: 0.9)
        }
    }

    /// From the old place, faint, to the node, strongest: the fade points the way it moved.
    private func drawTrail(_ canvas: GraphicsContext, _ node: Node) {
        guard hypot(node.point.x - node.past.x, node.point.y - node.past.y) >= Self.minimumTrail else { return }
        var line = Path()
        line.move(to: node.past)
        line.addLine(to: node.point)
        let tint = node.line.tint
        let fade = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [tint.opacity(0.1), tint.opacity(0.75)]), startPoint: node.past, endPoint: node.point)
        let ghost = CGRect(x: node.past.x - 2.5, y: node.past.y - 2.5, width: 5, height: 5)
        switch style {
        case .mono:
            canvas.stroke(line, with: fade, lineWidth: 1)
            canvas.stroke(Path(ghost), with: .color(tint.opacity(0.55)), lineWidth: 1)
        case .dot:
            canvas.stroke(line, with: fade, style: Self.dottedTrail)
            canvas.stroke(Path(ellipseIn: ghost), with: .color(tint.opacity(0.5)), lineWidth: 1)
        case .iris:
            canvas.stroke(line, with: .color(tint.opacity(0.4)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            canvas.stroke(Path(ellipseIn: ghost), with: .color(tint.opacity(0.4)), lineWidth: 0.8)
        }
    }
}
