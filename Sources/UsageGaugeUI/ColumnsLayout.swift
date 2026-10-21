import SwiftUI
import UsageGaugeCore

/// A column chart comparing the tools: per tool a column for the short window and one for the long
/// window, each as tall as what is left, with the figure above and the window's name below.
struct ColumnsLayout: View {
    static let toolsPerRow = 4

    let providers: [ProviderUsage]
    let now: Date
    let frozenAt: TimeInterval?

    var body: some View {
        ProviderGrid(providers: providers, columns: min(Self.toolsPerRow, max(providers.count, 1))) { index, usage, width in
            ColumnsBlock(usage: usage, index: index, width: width, now: now)
        }
    }
}

private struct ColumnsBlock: View {
    private static let columnSize = CGSize(width: 22, height: 84)
    private static let columnSpacing: CGFloat = 14

    let usage: ProviderUsage
    let index: Int
    let width: CGFloat
    let now: Date

    @Environment(\.panelStyle) private var style

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: Self.columnSpacing) {
                column(usage.session, label: "단", tint: tint)
                column(usage.weekly, label: "장", tint: tint)
            }
            VStack(spacing: 2) {
                ProviderName(usage: usage, index: index, tint: tint)
                caption
            }
        }
        .frame(width: width)
        .opacity(usage.isAvailable ? 1 : 0.5)
    }

    @ViewBuilder
    private var caption: some View {
        if usage.isAvailable {
            RevealingCaption(usage: usage, alignment: .center) {
                Text(countdown(until: usage.session?.resetsAt, now: now, style: style))
                    .font(Theme.figure(TypeScale.caption, .regular, style: style))
                    .foregroundStyle(Theme.faintText)
            }
        } else {
            Text("연결 안 됨").font(Theme.label(TypeScale.caption, style: style)).foregroundStyle(Theme.faintText)
        }
    }

    private func column(_ window: UsageWindow?, label fallback: String, tint: Color) -> some View {
        let remaining = window?.remainingPercent ?? 0
        return VStack(spacing: 5) {
            Text(percentText(window))
                .font(Theme.figure(TypeScale.body, .semibold, style: style))
                .foregroundStyle(Theme.alert(remaining) ?? Theme.primaryText)
                .fixedSize()
                .frame(width: Self.columnSize.width)
            VerticalMeter(remainingPercent: remaining, tint: tint, size: Self.columnSize)
            Text(window?.shortLabel ?? fallback)
                .font(Theme.label(TypeScale.micro, .medium, style: style))
                .foregroundStyle(Theme.faintText)
        }
    }
}

extension UsageWindow {
    /// "5h", "주", "월", … — the window's name in a few characters; nil when it has none.
    var shortLabel: String? {
        guard let label else { return nil }
        if label.hasSuffix("시간") { return label.dropLast(2) + "h" }
        return String(label.prefix(1))
    }
}
