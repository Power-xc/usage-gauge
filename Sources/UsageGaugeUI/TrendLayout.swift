import SwiftUI
import UsageGaugeCore

/// A line chart of each tool's short window over its whole period, with the remaining share in
/// large type above it and the burn rate in a caption. Two tools per row.
struct TrendLayout: View {
    static let toolsPerRow = 2

    let providers: [ProviderUsage]
    let history: UsageHistory
    let now: Date

    var body: some View {
        ProviderGrid(providers: providers, columns: min(Self.toolsPerRow, max(providers.count, 1))) { index, usage, width in
            TrendBlock(usage: usage, history: history, index: index, width: width, now: now)
        }
    }
}

private struct TrendBlock: View {
    private static let figureHeight: CGFloat = 36
    private static let dotPitch: CGFloat = 3.6
    /// Data this long makes a burn rate meaningful; below it the caption says it is still recording.
    private static let enoughData: TimeInterval = 10 * 60

    let usage: ProviderUsage
    let history: UsageHistory
    let index: Int
    let width: CGFloat
    let now: Date

    @Environment(\.panelStyle) private var style

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        VStack(alignment: .leading, spacing: 6) {
            ProviderName(usage: usage, index: index, tint: tint, marksBrand: true)
            if let window = usage.session ?? usage.weekly, usage.isAvailable {
                let series = TrendSeries(id: usage.id, window: window, history: history, now: now)
                figure(window).frame(height: Self.figureHeight, alignment: .leading)
                caption(series, window: window)
                TrendChart(series: series, tint: tint)
                axis(window)
            } else {
                Text("연결 안 됨")
                    .font(Theme.label(11, .semibold, style: style))
                    .foregroundStyle(Theme.mutedText)
                    .frame(height: Self.figureHeight, alignment: .leading)
                Text("CodexBar 확인")
                    .font(Theme.label(10, style: style))
                    .foregroundStyle(Theme.faintText)
                TrendChart(series: nil, tint: tint).opacity(0.5)
                axis(nil)
            }
        }
        .frame(width: width, alignment: .leading)
    }

    private func caption(_ series: TrendSeries?, window: UsageWindow) -> some View {
        let alert = Theme.alert(window.remainingPercent)
        var color = Theme.mutedText
        let text: String
        if let series, let rate = series.burnRate {
            let perHour = "시간당 \(max(1, Int(rate.rounded())))%"
            if let empty = series.projectedEmpty {
                text = "\(perHour) · \(countdown(until: empty, now: now, style: style)) 후 소진"
                color = alert ?? Theme.warning
            } else {
                text = "\(perHour) · 초기화까지 여유"
            }
        } else if let series, series.recordedSpan >= Self.enoughData {
            text = "최근 사용 없음 · 초기화까지 여유"
        } else {
            text = "기록 중 · 2분마다 쌓여요"
        }
        return Text(text)
            .font(Theme.figure(10, .regular, style: style))
            .foregroundStyle(color)
            .minimumScaleFactor(0.8)
    }

    /// "시작" at the window's start and the time to its reset at the right edge.
    private func axis(_ window: UsageWindow?) -> some View {
        HStack {
            Text("시작")
            Spacer(minLength: 4)
            Text(window?.resetsAt == nil ? "" : "초기화 \(countdown(until: window?.resetsAt, now: now, style: style))")
        }
        .font(Theme.figure(9, .regular, style: style))
        .foregroundStyle(Theme.faintText)
        .opacity(window == nil ? 0 : 1)
    }

    @ViewBuilder
    private func figure(_ window: UsageWindow) -> some View {
        let alert = Theme.alert(window.remainingPercent)
        let text = "\(window.displayPercent)"
        switch style {
        case .iris:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(text).font(Theme.display(32)).tracking(-0.8).foregroundStyle(alert ?? Theme.primaryText)
                Text("%").font(Theme.font(14, .medium)).foregroundStyle(Theme.mutedText)
            }
        case .dot:
            HStack(alignment: .bottom, spacing: Self.dotPitch) {
                DotMatrixText(text, pitch: Self.dotPitch, color: alert ?? .white)
                DotMatrixText("%", pitch: Self.dotPitch * 0.55, color: Theme.mutedText)
            }
        case .mono:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(text).font(Theme.mono(30, .semibold)).foregroundStyle(alert ?? .white)
                Text("%").font(Theme.mono(13, .medium)).foregroundStyle(Theme.mutedText)
            }
        }
    }
}
