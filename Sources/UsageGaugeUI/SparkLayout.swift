import SwiftUI
import UsageGaugeCore

/// A list, one full-width row per tool: name and short-window share on top, the window's bar, a
/// caption with both resets, and a strip of bars showing what was left over the window so far.
struct SparkLayout: View {
    let providers: [ProviderUsage]
    let now: Date
    let history: UsageHistory
    let frozenAt: TimeInterval?

    var body: some View {
        ProviderGrid(providers: providers, columns: 1) { index, usage, width in
            SparkBlock(usage: usage, index: index, width: width, now: now, history: history, frozenAt: frozenAt)
        }
    }
}

private struct SparkBlock: View {
    private static let rowSpacing: CGFloat = 6

    let usage: ProviderUsage
    let index: Int
    let width: CGFloat
    let now: Date
    let history: UsageHistory
    let frozenAt: TimeInterval?

    @Environment(\.panelStyle) private var style

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            titleRow(tint: tint)
            if let window = usage.session {
                WindowBar(remainingPercent: window.remainingPercent, tint: tint, frozenAt: frozenAt)
                caption(window)
                strip(window, tint: tint)
            }
        }
        .frame(width: width, alignment: .leading)
        .opacity(usage.isAvailable ? 1 : 0.5)
    }

    private func titleRow(tint: Color) -> some View {
        let remaining = usage.session?.remainingPercent ?? 0
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            ProviderTitle(usage: usage, index: index, tint: tint)
            Spacer(minLength: 6)
            if usage.isAvailable {
                Text(percentText(usage.session))
                    .font(Theme.figure(13, .semibold, style: style))
                    .foregroundStyle(Theme.alert(remaining) ?? Theme.primaryText)
            } else {
                Text("연결 안 됨")
                    .font(Theme.label(TypeScale.body, .semibold, style: style))
                    .foregroundStyle(Theme.mutedText)
            }
        }
    }

    /// "5시간 · 3시간 50분 후 초기화" on the left, "주간 37% · 3일 0시간" on the right.
    private func caption(_ window: UsageWindow) -> some View {
        let longLine = [usage.weekly?.label, usage.weekly.map { percentText($0) },
                        usage.weekly.map { countdown(until: $0.resetsAt, now: now, style: style) }]
            .compactMap { $0 }
        return RevealingCaption(usage: usage) {
            HStack {
                Text("\(window.label ?? "단기") · \(countdown(until: window.resetsAt, now: now, style: style)) 후 초기화")
                Spacer(minLength: 6)
                Text(longLine.joined(separator: " · "))
            }
            .font(Theme.figure(TypeScale.caption, .regular, style: style))
            .foregroundStyle(Theme.faintText)
        }
    }

    @ViewBuilder
    private func strip(_ window: UsageWindow, tint: Color) -> some View {
        let isRecording = history.samples(for: usage.id, in: window, now: now).count < 2
        let slices = SparkStrip.slices(width: width, style: style)
        let values = isRecording ? [Double?](repeating: nil, count: slices)
                                 : history.remainingPerSlice(for: usage.id, window: window, now: now, slices: slices)
        SparkStrip(values: values, nowIndex: window.elapsedFraction(now: now).map { min(slices - 1, Int($0 * Double(slices))) },
                   tint: tint)
            .overlay { if isRecording { RecordingNote() } }
    }
}
