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
    private static let figureSize: CGFloat = 32

    let usage: ProviderUsage
    let index: Int
    let width: CGFloat
    let now: Date

    @Environment(\.panelStyle) private var style

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        VStack(alignment: .leading, spacing: 6) {
            ProviderName(usage: usage, index: index, tint: tint)
            if usage.isAvailable {
                PercentFigure(window: usage.session, size: Self.figureSize).frame(height: Self.figureHeight, alignment: .leading)
                RevealingCaption(usage: usage) {
                    Text(detailLine)
                        .font(Theme.figure(TypeScale.caption, .regular, style: style))
                        .foregroundStyle(Theme.mutedText)
                }
            } else {
                Text("연결 안 됨")
                    .font(Theme.label(TypeScale.body, .semibold, style: style))
                    .foregroundStyle(Theme.mutedText)
                    .frame(height: Self.figureHeight, alignment: .leading)
                Text("CodexBar 확인")
                    .font(Theme.label(TypeScale.caption, style: style))
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
}
