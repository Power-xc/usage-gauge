import SwiftUI

/// Remaining share as a solid bar in the tool's colour over a solid track, ending in a white head
/// dot that breathes slowly. The compact variant (menu bar) keeps its light streak: a tail fading
/// into the head.
public struct CometBar: View {
    let remainingPercent: Double
    let thickness: CGFloat
    let color: Color
    let trackColor: Color
    let headColor: Color
    let isCompact: Bool
    let frozenAt: TimeInterval?

    private static let frameInterval: TimeInterval = 1.0 / 12
    private static let breathCycle: TimeInterval = 3.2
    private static let headScale: CGFloat = 1.7
    private static let dimmestHead = 0.7

    /// - Parameters:
    ///   - headColor: the brightest point of the streak; white on the panel, the bar colour on the menu bar.
    ///   - isCompact: for stacked menu bar bars: a fading streak with a stronger tail and no head dot, so
    ///     short bars stay visible and neighbours do not bleed into each other.
    ///   - frozenAt: fixed animation time for still renders; nil animates.
    public init(remainingPercent: Double, thickness: CGFloat, color: Color, trackColor: Color = Theme.track,
                headColor: Color = .white, isCompact: Bool = false, frozenAt: TimeInterval? = nil) {
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.thickness = thickness
        self.color = color
        self.trackColor = trackColor
        self.headColor = headColor
        self.isCompact = isCompact
        self.frozenAt = frozenAt
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: Self.frameInterval, paused: frozenAt != nil)) { context in
            let time = frozenAt ?? context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                draw(in: canvas, size: size, time: time.truncatingRemainder(dividingBy: 3600))
            }
        }
        .frame(height: isCompact ? thickness : thickness * Self.headScale * 2)
        .padding(.vertical, isCompact ? 0 : -(thickness * Self.headScale * 2 - thickness) / 2)
    }

    private func draw(in canvas: GraphicsContext, size: CGSize, time: Double) {
        let height = thickness
        let top = (size.height - height) / 2
        let track = Path(roundedRect: CGRect(x: 0, y: top, width: size.width, height: height), cornerRadius: height / 2)
        canvas.fill(track, with: .color(trackColor))
        guard remainingPercent > 0 else { return }

        let length = max(height * 2, size.width * remainingPercent / 100)
        let bar = Path(roundedRect: CGRect(x: 0, y: top, width: length, height: height), cornerRadius: height / 2)
        guard !isCompact else {
            canvas.fill(bar, with: .linearGradient(
                Gradient(stops: [
                    .init(color: color.opacity(0.45), location: 0),
                    .init(color: color.opacity(0.75), location: 0.55),
                    .init(color: color, location: 0.88),
                    .init(color: headColor, location: 1),
                ]),
                startPoint: .zero, endPoint: CGPoint(x: length, y: 0)))
            return
        }
        canvas.fill(bar, with: .color(color))
        let breath = 0.5 + 0.5 * sin(time * 2 * .pi / Self.breathCycle)
        let radius = height * Self.headScale / 2
        let head = CGPoint(x: length - radius, y: size.height / 2)
        canvas.fill(Path(ellipseIn: CGRect(x: head.x - radius, y: head.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(headColor.opacity(Self.dimmestHead + (1 - Self.dimmestHead) * breath)))
    }
}
