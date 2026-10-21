import SwiftUI

/// Where the constellation's field sits inside its frame, and how shares map onto it.
struct ConstellationPlot {
    static let width = PanelLayout.contentWidth
    static let height: CGFloat = 200
    /// Room left of the field for the long window's caption.
    static let gutter: CGFloat = 28
    static let margin: CGFloat = 10
    /// Height of the caption row under the field.
    static let captionHeight: CGFloat = 16

    static let frame = CGRect(x: 0, y: 0, width: width, height: height + captionHeight)
    static let field = CGRect(x: gutter, y: margin, width: width - gutter - margin, height: height - 2 * margin)

    /// A unit position (y growing upward) as a point of the frame.
    static func point(_ unit: CGPoint) -> CGPoint {
        CGPoint(x: field.minX + unit.x * field.width, y: field.maxY - unit.y * field.height)
    }
}

/// The quiet scaffolding of the field: hairline axes with ticks at 0, 50 and 100, a faint cross at
/// the middle, corner hints for plenty and scarcity and the axes' captions.
struct ConstellationGuides: View {
    private static let tickLength: CGFloat = 4
    private static let ticks: [CGFloat] = [0, 0.5, 1]
    private static let dotPitch: CGFloat = 12
    private static let hintOpacity = 0.3

    @Environment(\.panelStyle) private var style

    var body: some View {
        let field = ConstellationPlot.field
        ZStack(alignment: .topLeading) {
            Canvas { canvas, _ in
                switch style {
                case .dot: drawDotGrid(canvas, field)
                case .mono, .iris: drawAxes(canvas, field)
                }
            }
            hint("여유").position(x: field.maxX - 12, y: field.minY + 8)
            hint("부족").position(x: field.minX + 12, y: field.maxY - 8)
            caption("장기 ↑")
                .frame(width: ConstellationPlot.gutter - 4, alignment: .leading)
                .position(x: (ConstellationPlot.gutter - 4) / 2, y: field.minY)
            caption("단기 →")
                .frame(width: field.width, alignment: .trailing)
                .position(x: field.midX, y: field.maxY + 14)
        }
        .frame(width: ConstellationPlot.frame.width, height: ConstellationPlot.frame.height)
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(Theme.label(TypeScale.micro, .medium, style: style)).tracking(0.6).foregroundStyle(.white.opacity(Self.hintOpacity))
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(Theme.label(TypeScale.micro, .medium, style: style)).foregroundStyle(Theme.faintText)
    }

    /// Mono and iris: an L of hairlines with ticks outside, and a cross through the middle.
    private func drawAxes(_ canvas: GraphicsContext, _ field: CGRect) {
        let isIris = style == .iris
        let axis = Color.white.opacity(isIris ? 0.16 : 0.2), cross = Color.white.opacity(isIris ? 0.07 : 0.06)
        let left = field.minX.rounded() + 0.5, bottom = field.maxY.rounded() + 0.5
        var axes = Path(), marks = Path(), middle = Path()
        axes.addRect(CGRect(x: left, y: field.minY, width: 0.01, height: field.height))
        axes.addRect(CGRect(x: field.minX, y: bottom, width: field.width, height: 0.01))
        for tick in Self.ticks {
            let y = (field.maxY - tick * field.height).rounded() + 0.5, x = (field.minX + tick * field.width).rounded() + 0.5
            marks.move(to: CGPoint(x: left - Self.tickLength, y: y))
            marks.addLine(to: CGPoint(x: left, y: y))
            marks.move(to: CGPoint(x: x, y: bottom))
            marks.addLine(to: CGPoint(x: x, y: bottom + Self.tickLength))
        }
        middle.move(to: CGPoint(x: field.minX, y: (field.midY).rounded() + 0.5))
        middle.addLine(to: CGPoint(x: field.maxX, y: (field.midY).rounded() + 0.5))
        middle.move(to: CGPoint(x: (field.midX).rounded() + 0.5, y: field.minY))
        middle.addLine(to: CGPoint(x: (field.midX).rounded() + 0.5, y: field.maxY))
        canvas.stroke(middle, with: .color(cross), lineWidth: 1)
        canvas.stroke(axes, with: .color(axis), lineWidth: 1)
        canvas.stroke(marks, with: .color(axis), lineWidth: 1)
    }

    /// Dot: a grid of faint dots, brighter along the axes.
    private func drawDotGrid(_ canvas: GraphicsContext, _ field: CGRect) {
        let columns = Int(field.width / Self.dotPitch), rows = Int(field.height / Self.dotPitch)
        var faint = Path(), axis = Path()
        for column in 0...columns {
            for row in 0...rows {
                let center = CGPoint(x: field.minX + CGFloat(column) * Self.dotPitch, y: field.maxY - CGFloat(row) * Self.dotPitch)
                let isAxis = column == 0 || row == 0
                let radius: CGFloat = isAxis ? 1.1 : 0.8
                let dot = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                if isAxis { axis.addEllipse(in: dot) } else { faint.addEllipse(in: dot) }
            }
        }
        canvas.fill(faint, with: .color(.white.opacity(0.07)))
        canvas.fill(axis, with: .color(.white.opacity(0.2)))
    }
}
