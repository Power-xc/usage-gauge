import SwiftUI
import UsageGaugeCore

/// One tool's mark on the field: a marker, a short leader and a tag with its name and both
/// shares ("CLAUDE 94 · 37"). In the mono style that is a solid square and a 1 px outlined tag, in
/// dot a cluster of dots and bare dot-matrix figures, in iris a solid point in a thin ring and a flat chip.
/// The view is as large as marker and tag together and centred on neither: the marker sits at the
/// end the tag leaves from, so the field places it by `markerOffset`.
struct ConstellationNode: View {
    private static let dotPitch: CGFloat = 3.1
    private static let dotSize: CGFloat = 2.3
    private static let ringSize: CGFloat = 13
    private static let figurePitch: CGFloat = 1.2
    private static let chipRadius: CGFloat = 6
    /// Iris chips are one flat tone, dark enough to hide the links behind them.
    private static let irisChip = Color(white: 0.14).opacity(0.94)
    /// Dot-style tags are knocked out of the card's tone so dotted links do not run through them.
    private static let cardTone = Color(white: 0.1)

    let usage: ProviderUsage
    let placement: TagPlacement
    let tagWidth: CGFloat

    @Environment(\.panelStyle) private var style

    /// Size of the view: marker and tag side by side, tall enough for the tag's shift.
    static func size(tagWidth: CGFloat, placement: TagPlacement) -> CGSize {
        CGSize(width: TagLayout.reach + TagLayout.markerSize / 2 + tagWidth,
               height: TagLayout.height + 2 * abs(placement.offset))
    }

    /// Where the marker's centre sits inside the view.
    static func markerOffset(tagWidth: CGFloat, placement: TagPlacement) -> CGPoint {
        let size = size(tagWidth: tagWidth, placement: placement)
        let edge = TagLayout.markerSize / 2
        return CGPoint(x: placement.side == .right ? edge : size.width - edge, y: size.height / 2)
    }

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        let size = Self.size(tagWidth: tagWidth, placement: placement)
        let marker = Self.markerOffset(tagWidth: tagWidth, placement: placement)
        let direction: CGFloat = placement.side == .right ? 1 : -1
        let tagEdge = CGPoint(x: marker.x + direction * TagLayout.reach, y: marker.y + placement.offset)
        ZStack(alignment: .topLeading) {
            leader(from: marker, to: tagEdge, tint: tint)
            tag(tint: tint)
                .frame(width: tagWidth, height: TagLayout.height, alignment: placement.side == .right ? .leading : .trailing)
                .position(x: tagEdge.x + direction * tagWidth / 2, y: tagEdge.y)
            markerView(tint: tint).position(marker)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: Marker and leader

    @ViewBuilder
    private func markerView(tint: Color) -> some View {
        switch style {
        case .mono:
            Rectangle().fill(tint).frame(width: TagLayout.markerSize, height: TagLayout.markerSize)
        case .dot:
            Canvas { canvas, size in
                let origin = CGPoint(x: size.width / 2, y: size.height / 2)
                for row in -1...1 {
                    for column in -1...1 {
                        let isCorner = row != 0 && column != 0
                        let center = CGPoint(x: origin.x + CGFloat(column) * Self.dotPitch, y: origin.y + CGFloat(row) * Self.dotPitch)
                        canvas.fill(Path(ellipseIn: CGRect(x: center.x - Self.dotSize / 2, y: center.y - Self.dotSize / 2,
                                                           width: Self.dotSize, height: Self.dotSize)),
                                    with: .color(tint.opacity(isCorner ? 0.55 : 1)))
                    }
                }
            }
            .frame(width: 3 * Self.dotPitch, height: 3 * Self.dotPitch)
        case .iris:
            ZStack {
                Circle().strokeBorder(tint.opacity(0.55), lineWidth: 1).frame(width: Self.ringSize, height: Self.ringSize)
                Circle().fill(tint).frame(width: TagLayout.markerSize - 1, height: TagLayout.markerSize - 1)
            }
        }
    }

    @ViewBuilder
    private func leader(from start: CGPoint, to end: CGPoint, tint: Color) -> some View {
        let line = Path { $0.move(to: start); $0.addLine(to: end) }
        switch style {
        case .mono: line.stroke(tint.opacity(0.7), lineWidth: 1)
        case .dot: line.stroke(tint.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.01, 3]))
        case .iris: line.stroke(tint.opacity(0.6), lineWidth: 0.8)
        }
    }

    // MARK: Tag

    @ViewBuilder
    private func tag(tint: Color) -> some View {
        let short = usage.session, long = usage.weekly
        switch style {
        case .mono:
            HStack(spacing: 5) {
                Text(usage.title.uppercased()).font(Theme.mono(9, .semibold)).tracking(0.4).foregroundStyle(.white.opacity(0.7))
                figure(short, fallback: Theme.primaryText, font: Theme.mono(9, .semibold))
                Text("·").font(Theme.mono(9)).foregroundStyle(Theme.faintText)
                figure(long, fallback: Theme.mutedText, font: Theme.mono(9))
            }
            .padding(.horizontal, 6)
            .frame(height: TagLayout.height)
            .background(Color.black)
            .overlay(Rectangle().strokeBorder(tint.opacity(0.85), lineWidth: 1))
        case .dot:
            HStack(spacing: 5) {
                Text(usage.title.uppercased()).font(Theme.mono(9, .semibold)).tracking(0.5).foregroundStyle(.white.opacity(0.7))
                dotFigure(short, fallback: Theme.primaryText)
                Text("·").font(Theme.mono(9)).foregroundStyle(Theme.faintText)
                dotFigure(long, fallback: Theme.mutedText)
            }
            .padding(.horizontal, 4)
            .frame(height: TagLayout.height)
            .background(Self.cardTone)
        case .iris:
            HStack(spacing: 5) {
                Text(usage.title).font(Theme.font(10, .semibold)).foregroundStyle(.white.opacity(0.88))
                figure(short, fallback: Theme.primaryText, font: Theme.number(10))
                Text("·").font(Theme.font(10)).foregroundStyle(Theme.faintText)
                figure(long, fallback: Theme.mutedText, font: Theme.number(10, .regular))
            }
            .padding(.horizontal, 8)
            .frame(height: TagLayout.height)
            .background(RoundedRectangle(cornerRadius: Self.chipRadius, style: .continuous).fill(Self.irisChip))
        }
    }

    private func figure(_ window: UsageWindow?, fallback: Color, font: Font) -> some View {
        Text(window.map { "\($0.displayPercent)" } ?? ResetCountdown.unknown)
            .font(font)
            .foregroundStyle(window.flatMap { Theme.alert($0.remainingPercent) } ?? fallback)
    }

    @ViewBuilder
    private func dotFigure(_ window: UsageWindow?, fallback: Color) -> some View {
        DotMatrixText(window.map { "\($0.displayPercent)" } ?? ResetCountdown.unknown, pitch: Self.figurePitch,
                      color: window.flatMap { Theme.alert($0.remainingPercent) } ?? fallback)
    }

    /// An estimate of the tag's width, enough to keep neighbouring tags apart.
    static func tagWidth(for usage: ProviderUsage, style: PanelStyle) -> CGFloat {
        let digits = [usage.session, usage.weekly].map { $0.map { String($0.displayPercent).count } ?? 1 }
        switch style {
        case .mono:
            return CGFloat(usage.title.count) * 6 + CGFloat(digits.reduce(0, +)) * 5.4 + 3 * 5 + 5.4 + 12
        case .dot:
            return CGFloat(usage.title.count) * 6.1 + CGFloat(digits.reduce(0) { $0 + $1 * 6 - 1 }) * figurePitch + 3 * 5 + 5.4 + 8
        case .iris:
            return CGFloat(usage.title.count) * 6.4 + CGFloat(digits.reduce(0, +)) * 6 + 3 * 5 + 4 + 16
        }
    }
}
