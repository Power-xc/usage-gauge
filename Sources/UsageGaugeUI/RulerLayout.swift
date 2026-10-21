import SwiftUI
import UsageGaugeCore

/// A vertical ruler per tool, side by side: the short window's share runs up it as a line that
/// bulges around a knob, with the share in large type beside the knob, the long window as a notch
/// on the other side, and the name and countdown underneath.
struct RulerLayout: View {
    static let toolsPerRow = 4

    let providers: [ProviderUsage]
    let now: Date

    var body: some View {
        ProviderGrid(providers: providers, columns: min(Self.toolsPerRow, max(providers.count, 1))) { index, usage, width in
            RulerBlock(usage: usage, index: index, width: width, now: now)
        }
    }
}

private struct RulerBlock: View {
    private static let height: CGFloat = 190
    /// A ruler never grows wider than this; in a wider cell it is centred.
    private static let maxWidth: CGFloat = 148
    private static let figureRange: ClosedRange<CGFloat> = 20...34

    let usage: ProviderUsage
    let index: Int
    let width: CGFloat
    let now: Date

    @Environment(\.panelStyle) private var style

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        let content = min(width, Self.maxWidth)
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                RulerTrack(tint: tint, notchLabel: usage.isAvailable ? usage.weekly.map(Self.notchLabel) : nil,
                           isActive: usage.session != nil, remaining: usage.session?.remainingPercent ?? 0,
                           longRemaining: usage.weekly?.remainingPercent ?? 0)
                    .frame(width: content, height: Self.height)
                readout(content: content)
            }
            .frame(width: content, height: Self.height, alignment: .topLeading)
            VStack(alignment: .leading, spacing: 3) {
                ProviderName(usage: usage, index: index, tint: tint)
                RevealingCaption(usage: usage) {
                    Text(caption)
                        .font(Theme.figure(TypeScale.caption, .regular, style: style))
                        .foregroundStyle(Theme.faintText)
                }
            }
        }
        .frame(width: content, alignment: .leading)
        .frame(width: width)
        .opacity(usage.isAvailable ? 1 : 0.5)
    }

    /// The share beside the knob, as tall as the ruler's end padding so it fits at 0 and at 100.
    @ViewBuilder
    private func readout(content: CGFloat) -> some View {
        if let session = usage.session {
            let size = min(Self.figureRange.upperBound, max(Self.figureRange.lowerBound,
                                                           (content - RulerTrack.Metrics.figureX - 6) / 2.3))
            PercentFigure(window: session, size: size)
                .frame(height: size, alignment: .leading)
                .offset(x: RulerTrack.Metrics.figureX + 4, y: RulerTrack.Metrics.y(of: session.remainingPercent, in: Self.height) - size / 2)
        } else if !usage.isAvailable {
            Text("연결 안 됨")
                .font(Theme.label(TypeScale.caption, .semibold, style: style))
                .foregroundStyle(Theme.mutedText)
                .offset(x: RulerTrack.Metrics.figureX, y: Self.height / 2)
        }
    }

    /// "3h 50m · 주 37%": when the short window resets, then the long window's share.
    private var caption: String {
        guard usage.isAvailable else { return "CodexBar 확인" }
        let reset = countdown(until: (usage.session ?? usage.weekly)?.resetsAt, now: now, style: style)
        guard let weekly = usage.weekly else { return reset }
        return "\(reset) · \(Self.notchLabel(weekly)) \(weekly.displayPercent)%"
    }

    /// One syllable for the long window: 주 (weekly), 월 (monthly), 일 (daily).
    private static func notchLabel(_ window: UsageWindow) -> String {
        switch window.label {
        case "월간": "월"
        case "일간": "일"
        default: "주"
        }
    }
}
