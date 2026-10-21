import SwiftUI

/// Remaining share drawn as a streak of light: a fading tail, a white-hot head with a soft flare,
/// and a pulse that runs along the tail towards the head.
public struct CometBar: View {
    let remainingPercent: Double
    let thickness: CGFloat
    let color: Color
    let trackColor: Color
    let headColor: Color
    let isCompact: Bool
    let frozenAt: TimeInterval?

    private static let frameInterval: TimeInterval = 1.0 / 12
    private static let pulseCycle: TimeInterval = 2.8

    /// The bar is `thickness` tall and centred in a taller view so the head's flare has room.
    /// - Parameters:
    ///   - headColor: the brightest point of the streak; white on the panel, the bar colour on the menu bar.
    ///   - isCompact: for stacked menu bar bars: a stronger tail and no flare, so short bars stay visible
    ///     and neighbours do not bleed into each other.
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
                draw(in: canvas, size: size, phase: (time / Self.pulseCycle).truncatingRemainder(dividingBy: 1))
            }
        }
        .frame(height: isCompact ? thickness : thickness * 3)
        .padding(.vertical, isCompact ? 0 : -thickness)
    }

    private func draw(in canvas: GraphicsContext, size: CGSize, phase: Double) {
        let height = thickness
        let top = (size.height - height) / 2
        let track = Path(roundedRect: CGRect(x: 0, y: top, width: size.width, height: height), cornerRadius: height / 2)
        canvas.fill(track, with: .color(trackColor))
        guard remainingPercent > 0 else { return }

        let length = max(height * 2, size.width * remainingPercent / 100)
        let bar = Path(roundedRect: CGRect(x: 0, y: top, width: length, height: height), cornerRadius: height / 2)
        canvas.fill(bar, with: .linearGradient(
            Gradient(stops: [
                .init(color: color.opacity(isCompact ? 0.45 : 0.08), location: 0),
                .init(color: color.opacity(isCompact ? 0.75 : 0.55), location: 0.55),
                .init(color: color, location: 0.88),
                .init(color: headColor, location: 1),
            ]),
            startPoint: .zero, endPoint: CGPoint(x: length, y: 0)))

        // Pulse travelling along the tail, fading out as it reaches the head.
        let pulseX = length * phase
        var pulse = canvas
        pulse.clip(to: bar)
        pulse.opacity = sin(phase * .pi)
        pulse.fill(Path(CGRect(x: pulseX - height * 6, y: top, width: height * 12, height: height)),
                   with: .linearGradient(Gradient(colors: [headColor.opacity(0), headColor.opacity(0.7), headColor.opacity(0)]),
                                         startPoint: CGPoint(x: pulseX - height * 6, y: 0),
                                         endPoint: CGPoint(x: pulseX + height * 6, y: 0)))

        guard !isCompact else { return }
        // Flare round the head.
        let head = CGPoint(x: length - height / 2, y: size.height / 2)
        let flare = height * 1.4
        canvas.fill(Path(ellipseIn: CGRect(x: head.x - flare * 1.6, y: head.y - flare, width: flare * 3.2, height: flare * 2)),
                    with: .radialGradient(Gradient(colors: [headColor.opacity(0.75), color.opacity(0.35), color.opacity(0)]),
                                          center: head, startRadius: 0, endRadius: flare * 1.6))
    }
}
