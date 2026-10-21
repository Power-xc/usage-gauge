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
    private static let figureSize: CGFloat = 32
    private static let hour: TimeInterval = 3600

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
        let usedLastHour = isRecording ? nil : self.usedLastHour(window)
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            usedFigure(usedLastHour)
            Text(usedLastHour == 0 ? "최근 1시간 사용 없음" : "최근 1시간 사용")
                .font(Theme.label(9.5, style: style))
                .foregroundStyle(Theme.faintText)
        }
        .frame(height: Self.figureHeight, alignment: .leading)
        HistogramColumns(values: isRecording ? [] : used, tint: tint)
            .overlay { if isRecording { RecordingNote() } }
        footer(window)
    }

    /// What the window lost over the last hour, summed from the recorded drops.
    private func usedLastHour(_ window: UsageWindow) -> Double {
        let recent = history.points(for: usage.id, window: window, now: now).filter { $0.at >= now.addingTimeInterval(-Self.hour) }
        return zip(recent, recent.dropFirst()).reduce(0) { $0 + max(0, $1.0.remaining - $1.1.remaining) }
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

    /// The share used over the last hour, in the style's large figure.
    private func usedFigure(_ used: Double?) -> some View {
        StyleFigure(text: used.map { "\(Int($0.rounded()))" } ?? ResetCountdown.unknown, showsPercent: used != nil,
                    color: Theme.primaryText, size: Self.figureSize)
    }
}

/// Small status at the end of a footer: a dot and the projected run-out in the alert colour, or
/// "여유". Light and colour only, no frame.
struct StatusPill: View {
    let text: String
    let color: Color

    @Environment(\.panelStyle) private var style

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: style == .mono ? 0 : 2)
                .fill(color)
                .frame(width: 4, height: 4)
                .shadow(color: style == .iris ? color.opacity(0.9) : .clear, radius: 3)
            Text(text)
                .font(Theme.figure(9.5, .semibold, style: style))
                .foregroundStyle(color)
        }
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
