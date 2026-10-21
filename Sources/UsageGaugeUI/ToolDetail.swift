import SwiftUI
import UsageGaugeCore

private enum DetailMetrics {
    static let dialSize: CGFloat = 120
    static let columnSpacing: CGFloat = 18
    static let windowSpacing: CGFloat = 14
}

/// One tool in full: a large dial beside its plan and both windows, each with its remaining share,
/// a bar, the reset as a clock time and a countdown, and when the numbers were measured.
/// `extras` is the slot under the windows for further sections (a history chart, say).
struct ToolDetail<Extras: View>: View {
    let usage: ProviderUsage
    let index: Int
    let now: Date
    let frozenAt: TimeInterval?
    @ViewBuilder let extras: () -> Extras

    @Environment(\.panelStyle) private var style

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        VStack(alignment: .leading, spacing: DetailMetrics.windowSpacing) {
            HStack(alignment: .top, spacing: DetailMetrics.columnSpacing) {
                SessionGauge(window: usage.isAvailable ? usage.session : nil, tint: tint, size: DetailMetrics.dialSize,
                             now: now, frozenAt: frozenAt)
                    .background {
                        if style == .iris { DetailGlow(tint: tint, dialSize: DetailMetrics.dialSize) }
                    }
                VStack(alignment: .leading, spacing: DetailMetrics.windowSpacing) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        ProviderName(usage: usage, index: index, tint: tint)
                        PlanTag(plan: usage.plan)
                        Spacer(minLength: 0)
                        if let measured = HoverDetail.measured(usage) {
                            Text(measured).font(Theme.figure(9.5, .regular, style: style)).foregroundStyle(Theme.faintText)
                        }
                    }
                    if usage.isAvailable {
                        DetailWindow(window: usage.session, fallbackLabel: "단기", tint: tint, now: now, frozenAt: frozenAt)
                        DetailWindow(window: usage.weekly, fallbackLabel: "장기", tint: tint, now: now, frozenAt: frozenAt)
                    } else {
                        notConnected
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            extras()
        }
        .frame(width: PanelLayout.contentWidth, alignment: .leading)
    }

    private var notConnected: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("연결 안 됨").font(Theme.label(12, .semibold, style: style)).foregroundStyle(Theme.mutedText)
            Text(usage.errorMessage ?? "CodexBar 로그인을 확인하세요")
                .font(Theme.label(10, style: style))
                .foregroundStyle(Theme.faintText)
                .lineLimit(2)
        }
    }
}

/// Label and remaining share over a bar, then "오후 4:00 초기화 · 3시간 50분 후".
private struct DetailWindow: View {
    let window: UsageWindow?
    let fallbackLabel: String
    let tint: Color
    let now: Date
    let frozenAt: TimeInterval?

    @Environment(\.panelStyle) private var style

    var body: some View {
        let remaining = window?.remainingPercent ?? 0
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(window?.label ?? fallbackLabel)
                    .font(Theme.label(10.5, .medium, style: style))
                    .foregroundStyle(Theme.mutedText)
                Text(percentText(window))
                    .font(Theme.figure(18, .semibold, style: style))
                    .foregroundStyle(Theme.alert(remaining) ?? Theme.primaryText)
                Spacer(minLength: 0)
            }
            WindowBar(remainingPercent: remaining, tint: tint, frozenAt: frozenAt)
            Text(resetLine)
                .font(Theme.figure(10, .regular, style: style))
                .foregroundStyle(Theme.faintText)
        }
    }

    private var resetLine: String {
        guard let reset = window?.resetsAt else { return "초기화 시각 모름" }
        return "\(HoverDetail.clock(reset)) 초기화 · \(countdown(until: reset, now: now, style: style)) 후"
    }
}

/// The tool's colour glowing through the glass from behind the large dial.
private struct DetailGlow: View {
    let tint: Color
    let dialSize: CGFloat

    var body: some View {
        RadialGradient(colors: [tint.opacity(0.28), tint.opacity(0)], center: .center,
                       startRadius: dialSize * 0.3, endRadius: dialSize * 0.7)
            .frame(width: dialSize * 1.4, height: dialSize * 1.4)
            .allowsHitTesting(false)
    }
}
