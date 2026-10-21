import SwiftUI
import UsageGaugeCore

/// Per tool a starburst of the short window's use, with the remaining share in its middle and the
/// name, burn rate and run-out beside it. Two tools sit in a row.
struct BurstLayout: View {
    static let toolsPerRow = 2

    let providers: [ProviderUsage]
    let now: Date
    let history: UsageHistory

    var body: some View {
        ProviderGrid(providers: providers, columns: min(Self.toolsPerRow, max(providers.count, 1))) { index, usage, width in
            BurstBlock(usage: usage, index: index, width: width, now: now, history: history)
        }
    }
}

private struct BurstBlock: View {
    private static let figureSize: CGFloat = 20
    private static let spacing: CGFloat = 12

    let usage: ProviderUsage
    let index: Int
    let width: CGFloat
    let now: Date
    let history: UsageHistory

    @Environment(\.panelStyle) private var style

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        HStack(alignment: .center, spacing: Self.spacing) {
            mark(tint: tint)
            VStack(alignment: .leading, spacing: 5) {
                ProviderTitle(usage: usage, index: index, tint: tint)
                details
            }
            Spacer(minLength: 0)
        }
        .frame(width: width, alignment: .leading)
        .opacity(usage.isAvailable ? 1 : 0.5)
    }

    private var window: UsageWindow? { usage.isAvailable ? usage.session : nil }

    private func mark(tint: Color) -> some View {
        let isRecording = window.map { history.samples(for: usage.id, in: $0, now: now).count < 2 } ?? true
        let used = window.map { history.usedPerSlice(for: usage.id, window: $0, now: now, slices: BurstRays.slices) } ?? []
        return BurstRays(values: isRecording ? [] : used, tint: tint)
            .overlay {
                VStack(spacing: 1) {
                    PercentFigure(window: window, size: Self.figureSize)
                    Text(window?.label ?? "")
                        .font(Theme.label(TypeScale.micro, style: style))
                        .foregroundStyle(Theme.faintText)
                }
            }
    }

    /// "시간당 12%" over "소진 2h 10m" in the alert colour, or "여유" when it lasts to the reset.
    @ViewBuilder
    private var details: some View {
        if let window {
            let burn = history.burnRate(for: usage.id, window: window, now: now)
            let empty = history.projectedEmpty(for: usage.id, window: window, now: now)
            VStack(alignment: .leading, spacing: 2) {
                if let burn {
                    Text("시간당 \(max(1, Int(burn.rounded())))%").foregroundStyle(Theme.mutedText)
                }
                if let empty {
                    Text("소진 \(countdown(until: empty, now: now, style: style))")
                        .foregroundStyle(Theme.alert(window.remainingPercent) ?? Theme.warning)
                } else {
                    Text(burn == nil ? "사용 없음 · 여유" : "여유").foregroundStyle(Theme.mutedText)
                }
                RevealingCaption(usage: usage, isCompact: true) {
                    Text("초기화 \(countdown(until: window.resetsAt, now: now, style: style))").foregroundStyle(Theme.faintText)
                }
            }
            .font(Theme.figure(TypeScale.caption, .regular, style: style))
        } else {
            Text(usage.isAvailable ? "단기 창 없음" : "연결 안 됨")
                .font(Theme.label(TypeScale.body, .semibold, style: style))
                .foregroundStyle(Theme.mutedText)
        }
    }
}
