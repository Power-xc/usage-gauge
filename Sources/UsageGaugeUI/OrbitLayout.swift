import SwiftUI
import UsageGaugeCore

/// One chart for every tool: concentric rings (the first tool outermost) lit for the short
/// window's remaining share, the lowest of them in the middle, and a legend with both windows and
/// the reset countdown per tool.
struct OrbitLayout: View {
    private static let chartSize: CGFloat = 150
    private static let maxRings = 6
    private static let gap: CGFloat = 20

    let providers: [ProviderUsage]
    let now: Date

    @Environment(\.panelStyle) private var style

    var body: some View {
        VStack(spacing: 0) {
            if style == .mono { GridRule(isVertical: false) }
            HStack(spacing: Self.gap) {
                chart
                OrbitLegend(providers: providers, now: now)
            }
            .frame(width: PanelLayout.contentWidth)
            .padding(style == .mono ? Theme.panelPadding : 0)
        }
    }

    private var chart: some View {
        let rings = providers.prefix(Self.maxRings).map {
            OrbitRing(remainingPercent: $0.isAvailable ? $0.session?.remainingPercent : nil, tint: Theme.brand(for: $0.id))
        }
        let inner = OrbitRings.innerRadius(ringCount: rings.count, size: Self.chartSize)
        return ZStack {
            OrbitRings(rings: rings)
            OrbitCentre(lowest: lowest).frame(width: inner * 2 - 6)
        }
        .frame(width: Self.chartSize, height: Self.chartSize)
    }

    /// The tool with the least left in its short window.
    private var lowest: ProviderUsage? {
        providers.filter { $0.isAvailable && $0.session != nil }
            .min { ($0.session?.remainingPercent ?? 0) < ($1.session?.remainingPercent ?? 0) }
    }
}

/// The lowest remaining share and whose it is.
private struct OrbitCentre: View {
    private static let figureSize: CGFloat = 24

    let lowest: ProviderUsage?

    @Environment(\.panelStyle) private var style

    var body: some View {
        VStack(spacing: 3) {
            ShapeFigure(window: lowest?.session, size: Self.figureSize)
            Text(lowest.map { "최저 · \($0.title)" } ?? "연결 안 됨")
                .font(Theme.label(8.5, .medium, style: style))
                .foregroundStyle(Theme.faintText)
        }
        .minimumScaleFactor(0.7)
    }
}

/// One row per tool in aligned columns: name, short window, long window and the short window's
/// countdown.
private struct OrbitLegend: View {
    private static let rowHeight: CGFloat = 21
    private static let shortWidth: CGFloat = 44
    private static let longWidth: CGFloat = 40
    private static let countdownWidth: CGFloat = 64

    let providers: [ProviderUsage]
    let now: Date

    @Environment(\.panelStyle) private var style

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                heading("단기", width: Self.shortWidth)
                heading("장기", width: Self.longWidth)
                heading("초기화", width: Self.countdownWidth)
            }
            .frame(height: 14)
            ForEach(Array(providers.enumerated()), id: \.offset) { _, usage in
                row(usage)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func heading(_ text: String, width: CGFloat) -> some View {
        Text(text).font(Theme.label(8.5, .medium, style: style)).foregroundStyle(Theme.faintText)
            .frame(width: width, alignment: .trailing)
    }

    private func row(_ usage: ProviderUsage) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                bullet(Theme.brand(for: usage.id))
                Text(style == .iris ? usage.title : usage.title.uppercased())
                    .font(style == .iris ? Theme.font(12, .semibold) : Theme.mono(11, .semibold))
                    .tracking(style == .iris ? 0 : 0.5)
            }
            Spacer(minLength: 4)
            if usage.isAvailable {
                Text(percentText(usage.session))
                    .font(Theme.figure(11.5, .semibold, style: style))
                    .foregroundStyle(usage.session.flatMap { Theme.alert($0.remainingPercent) } ?? Theme.primaryText)
                    .frame(width: Self.shortWidth, alignment: .trailing)
                Text(percentText(usage.weekly))
                    .font(Theme.figure(9.5, .regular, style: style))
                    .foregroundStyle(usage.weekly.flatMap { Theme.alert($0.remainingPercent) } ?? Theme.mutedText)
                    .frame(width: Self.longWidth, alignment: .trailing)
                Text(countdown(until: usage.session?.resetsAt, now: now, style: style))
                    .font(Theme.figure(9.5, .regular, style: style))
                    .foregroundStyle(Theme.faintText)
                    .frame(width: Self.countdownWidth, alignment: .trailing)
            } else {
                Text("연결 안 됨").font(Theme.label(10, .medium, style: style)).foregroundStyle(Theme.faintText)
            }
        }
        .frame(height: Self.rowHeight)
    }

    @ViewBuilder
    private func bullet(_ tint: Color) -> some View {
        if style == .mono {
            Rectangle().fill(tint).frame(width: 6, height: 6)
        } else {
            Circle().fill(tint).frame(width: 6.5, height: 6.5)
        }
    }
}
