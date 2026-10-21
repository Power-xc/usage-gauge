import SwiftUI
import UsageGaugeCore

/// A compact list: the tool's name on the left, and a row per window to its right with a label,
/// the style's bar, the remaining share and the time to reset.
struct BarsLayout: View {
    let providers: [ProviderUsage]
    let now: Date
    let frozenAt: TimeInterval?

    var body: some View {
        ProviderGrid(providers: providers, columns: 1) { index, usage, _ in
            BarsBlock(usage: usage, index: index, now: now, frozenAt: frozenAt)
        }
    }
}

private struct BarsBlock: View {
    private static let nameWidth: CGFloat = 120
    private static let rowSpacing: CGFloat = 6

    let usage: ProviderUsage
    let index: Int
    let now: Date
    let frozenAt: TimeInterval?

    @Environment(\.panelStyle) private var style

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                ProviderName(usage: usage, index: index, tint: tint)
                RevealingCaption(usage: usage, isCompact: true) { PlanTag(plan: usage.plan) }
                    .frame(minHeight: TypeScale.micro)
            }
            .frame(width: Self.nameWidth, alignment: .leading)
            if usage.isAvailable {
                VStack(spacing: Self.rowSpacing) {
                    BarRow(window: usage.session, fallbackLabel: "단기", tint: tint, now: now, frozenAt: frozenAt)
                    BarRow(window: usage.weekly, fallbackLabel: "장기", tint: tint, now: now, frozenAt: frozenAt)
                }
            } else {
                Text("연결 안 됨")
                    .font(Theme.label(TypeScale.body, .semibold, style: style))
                    .foregroundStyle(Theme.mutedText)
                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: 34)
    }
}

/// Label, bar, share and countdown of one window, on a single line.
private struct BarRow: View {
    private static let labelWidth: CGFloat = 38
    private static let figureWidth: CGFloat = 36
    private static let countdownWidth: CGFloat = 56

    let window: UsageWindow?
    let fallbackLabel: String
    let tint: Color
    let now: Date
    let frozenAt: TimeInterval?

    @Environment(\.panelStyle) private var style

    var body: some View {
        let remaining = window?.remainingPercent ?? 0
        HStack(spacing: 8) {
            Text(window?.label ?? fallbackLabel)
                .font(Theme.label(TypeScale.caption, .medium, style: style))
                .foregroundStyle(Theme.mutedText)
                .frame(width: Self.labelWidth, alignment: .leading)
            WindowBar(remainingPercent: remaining, tint: tint, frozenAt: frozenAt)
            Text(percentText(window))
                .font(Theme.figure(TypeScale.body, .semibold, style: style))
                .foregroundStyle(Theme.alert(remaining) ?? Theme.primaryText)
                .frame(width: Self.figureWidth, alignment: .trailing)
            Text(countdown(until: window?.resetsAt, now: now, style: style))
                .font(Theme.figure(TypeScale.caption, .regular, style: style))
                .foregroundStyle(Theme.faintText)
                .frame(width: Self.countdownWidth, alignment: .trailing)
        }
        .frame(height: 14)
    }
}
