import SwiftUI
import UsageGaugeCore

/// The smallest form: per tool its name, the short window's remaining share in large type, and a
/// small line for the long window. Tools sit in a row, wrapping after four.
struct FiguresLayout: View {
    static let toolsPerRow = 4

    let providers: [ProviderUsage]
    let now: Date

    var body: some View {
        ProviderGrid(providers: providers, columns: min(Self.toolsPerRow, max(providers.count, 1))) { index, usage, width in
            FiguresBlock(usage: usage, index: index, width: width, now: now)
        }
    }
}

private struct FiguresBlock: View {
    private static let figureHeight: CGFloat = 36
    private static let dotPitch: CGFloat = 3.6

    let usage: ProviderUsage
    let index: Int
    let width: CGFloat
    let now: Date

    @Environment(\.panelStyle) private var style

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        VStack(alignment: .leading, spacing: 6) {
            ProviderName(usage: usage, index: index, tint: tint, marksBrand: true)
            if usage.isAvailable {
                figure(usage.session).frame(height: Self.figureHeight, alignment: .leading)
                Text(detailLine)
                    .font(Theme.figure(10, .regular, style: style))
                    .foregroundStyle(Theme.mutedText)
            } else {
                Text("연결 안 됨")
                    .font(Theme.label(11, .semibold, style: style))
                    .foregroundStyle(Theme.mutedText)
                    .frame(height: Self.figureHeight, alignment: .leading)
                Text("CodexBar 확인")
                    .font(Theme.label(10, style: style))
                    .foregroundStyle(Theme.faintText)
            }
        }
        .frame(width: width, alignment: .leading)
    }

    /// "주간 37% · 3h 50m": the long window's share and when the short one resets.
    private var detailLine: String {
        let label = usage.weekly?.label ?? "장기"
        return "\(label) \(percentText(usage.weekly)) · \(countdown(until: usage.session?.resetsAt, now: now, style: style))"
    }

    @ViewBuilder
    private func figure(_ window: UsageWindow?) -> some View {
        let alert = window.flatMap { Theme.alert($0.remainingPercent) }
        let text = window.map { "\($0.displayPercent)" } ?? ResetCountdown.unknown
        switch style {
        case .iris:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(text).font(Theme.display(32)).tracking(-0.8)
                    .foregroundStyle(alert ?? Theme.primaryText)
                if window != nil { Text("%").font(Theme.font(14, .medium)).foregroundStyle(Theme.mutedText) }
            }
        case .dot:
            HStack(alignment: .bottom, spacing: Self.dotPitch) {
                DotMatrixText(text, pitch: Self.dotPitch, color: alert ?? .white)
                if window != nil { DotMatrixText("%", pitch: Self.dotPitch * 0.55, color: Theme.mutedText) }
            }
        case .mono:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(text).font(Theme.mono(30, .semibold)).foregroundStyle(alert ?? .white)
                if window != nil { Text("%").font(Theme.mono(13, .medium)).foregroundStyle(Theme.mutedText) }
            }
        }
    }
}
