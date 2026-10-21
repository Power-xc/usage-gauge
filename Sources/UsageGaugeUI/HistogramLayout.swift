import SwiftUI
import UsageGaugeCore

/// Per tool a histogram of the short window's recent use: what was used in the last hour in large
/// type, a column per slice of the window, and whether the allowance lasts until the reset. Two
/// tools sit in a row.
struct HistogramLayout: View {
    static let toolsPerRow = 2
    static let slices = 24

    let providers: [ProviderUsage]
    let now: Date
    let history: UsageHistory

    var body: some View {
        ProviderGrid(providers: providers, columns: min(Self.toolsPerRow, max(providers.count, 1))) { index, usage, width in
            HistogramBlock(usage: usage, index: index, width: width, now: now, history: history)
        }
    }
}

private struct HistogramBlock: View {
    private static let figureHeight: CGFloat = 36
    private static let dotPitch: CGFloat = 3.6

    let usage: ProviderUsage
    let index: Int
    let width: CGFloat
    let now: Date
    let history: UsageHistory

    @Environment(\.panelStyle) private var style

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                ProviderName(usage: usage, index: index, tint: tint, marksBrand: true)
                PlanTag(plan: usage.plan)
            }
            if let window = usage.session {
                chart(window, tint: tint)
            } else {
                Text(usage.isAvailable ? "단기 창 없음" : "연결 안 됨")
                    .font(Theme.label(11, .semibold, style: style))
                    .foregroundStyle(Theme.mutedText)
                    .frame(height: Self.figureHeight + 6 + HistogramColumns.height, alignment: .topLeading)
            }
        }
        .frame(width: width, alignment: .leading)
    }

    @ViewBuilder
    private func chart(_ window: UsageWindow, tint: Color) -> some View {
        let isRecording = history.samples(for: usage.id, in: window, now: now).count < 2
        let used = history.usedPerSlice(for: usage.id, window: window, now: now, slices: HistogramLayout.slices)
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            figure(isRecording ? nil : history.burnRate(for: usage.id, window: window, now: now))
            Text("최근 1시간 사용")
                .font(Theme.label(9.5, style: style))
                .foregroundStyle(Theme.faintText)
        }
        .frame(height: Self.figureHeight, alignment: .leading)
        HistogramColumns(values: isRecording ? [] : used, tint: tint)
            .overlay { if isRecording { RecordingNote() } }
        footer(window)
    }

    private func footer(_ window: UsageWindow) -> some View {
        let remaining = window.remainingPercent
        let empty = history.projectedEmpty(for: usage.id, window: window, now: now)
        return HStack(spacing: 6) {
            Text("\(window.label ?? "단기") · 남은")
                .font(Theme.label(10, .medium, style: style))
                .foregroundStyle(Theme.mutedText)
            Text(percentText(window))
                .font(Theme.figure(10.5, .semibold, style: style))
                .foregroundStyle(Theme.alert(remaining) ?? Theme.primaryText)
            Spacer(minLength: 6)
            if let empty {
                StatusPill(text: "소진 \(countdown(until: empty, now: now, style: style))",
                           color: Theme.alert(remaining) ?? Theme.warning)
            } else {
                StatusPill(text: "여유", color: Theme.mutedText)
            }
        }
    }

    @ViewBuilder
    private func figure(_ used: Double?) -> some View {
        let text = used.map { "\(Int($0.rounded()))" } ?? ResetCountdown.unknown
        switch style {
        case .iris:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(text).font(Theme.display(32)).tracking(-0.8)
                if used != nil { Text("%").font(Theme.font(14, .medium)).foregroundStyle(Theme.mutedText) }
            }
        case .dot:
            HStack(alignment: .bottom, spacing: Self.dotPitch) {
                DotMatrixText(text, pitch: Self.dotPitch, color: .white)
                if used != nil { DotMatrixText("%", pitch: Self.dotPitch * 0.55, color: Theme.mutedText) }
            }
        case .mono:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(text).font(Theme.mono(30, .semibold))
                if used != nil { Text("%").font(Theme.mono(13, .medium)).foregroundStyle(Theme.mutedText) }
            }
        }
    }
}

/// Small outlined label at the end of a footer: the projected run-out in the alert colour, or "여유".
struct StatusPill: View {
    let text: String
    let color: Color

    @Environment(\.panelStyle) private var style

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: style == .mono ? 2 : 8, style: .continuous)
        Text(text)
            .font(Theme.figure(9.5, .semibold, style: style))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(shape.fill(color.opacity(0.12)))
            .overlay(shape.strokeBorder(color.opacity(0.35), lineWidth: 0.6))
    }
}

/// Shown in place of a chart while the history holds too little to draw.
struct RecordingNote: View {
    @Environment(\.panelStyle) private var style

    var body: some View {
        Text("기록 중 · 2분마다 쌓여요")
            .font(Theme.label(10, style: style))
            .foregroundStyle(Theme.faintText)
    }
}
