import SwiftUI
import UsageGaugeCore

/// Per tool a horizontal capsule filled to the short window's remaining share, with the long
/// window as a thin bar under it. Two tools sit in a row.
struct CapsuleLayout: View {
    static let toolsPerRow = 2

    let providers: [ProviderUsage]
    let now: Date
    let frozenAt: TimeInterval?

    var body: some View {
        ProviderGrid(providers: providers, columns: min(Self.toolsPerRow, max(providers.count, 1))) { index, usage, width in
            CapsuleBlock(usage: usage, index: index, width: width, now: now, frozenAt: frozenAt)
        }
    }
}

private struct CapsuleBlock: View {
    private static let figureSize: CGFloat = 26

    let usage: ProviderUsage
    let index: Int
    let width: CGFloat
    let now: Date
    let frozenAt: TimeInterval?

    @Environment(\.panelStyle) private var style

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    ProviderName(usage: usage, index: index, tint: tint)
                    PlanTag(plan: usage.plan)
                }
                Spacer(minLength: 8)
                readout
            }
            CapsuleBar(remainingPercent: usage.isAvailable ? usage.session?.remainingPercent ?? 0 : 0, tint: tint)
            LongWindowBar(window: usage.isAvailable ? usage.weekly : nil, tint: tint, now: now, frozenAt: frozenAt)
        }
        .frame(width: width, alignment: .leading)
    }

    /// The big share with the reset countdown under it, at the right end.
    @ViewBuilder
    private var readout: some View {
        VStack(alignment: .trailing, spacing: 3) {
            if usage.isAvailable {
                ShapeFigure(window: usage.session, size: Self.figureSize).frame(height: Self.figureSize, alignment: .trailing)
                Text(countdown(until: usage.session?.resetsAt, now: now, style: style))
                    .font(Theme.figure(9.5, .regular, style: style))
                    .foregroundStyle(Theme.faintText)
            } else {
                Text("연결 안 됨")
                    .font(Theme.label(11, .semibold, style: style))
                    .foregroundStyle(Theme.mutedText)
                    .frame(height: Self.figureSize, alignment: .trailing)
                Text("CodexBar 확인").font(Theme.label(9.5, style: style)).foregroundStyle(Theme.faintText)
            }
        }
    }
}
