import SwiftUI
import UsageGaugeCore

/// One chart for every tool: concentric rings (the first tool outermost) lit for the short
/// window's remaining share, the lowest of them in the middle, and a legend with both windows and
/// the reset countdown per tool. A tool is one ring and one legend row: pointing at either
/// focuses it (the middle then shows its share and the legend its times) and clicking opens it.
struct OrbitLayout: View {
    let providers: [ProviderUsage]
    let now: Date

    var body: some View {
        OrbitChart(providers: providers, now: now).toolFocusScope()
    }
}

private struct OrbitChart: View {
    static let chartSize: CGFloat = 150
    private static let maxRings = 6
    private static let gap: CGFloat = 20

    let providers: [ProviderUsage]
    let now: Date

    @State private var pointedRing: String?
    @Environment(\.panelStyle) private var style
    @Environment(\.toolFocus) private var focus
    @Environment(\.toolInteraction) private var interaction

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

    private var ringedProviders: [ProviderUsage] { Array(providers.prefix(Self.maxRings)) }

    private var chart: some View {
        let rings = ringedProviders.map {
            OrbitRing(remainingPercent: $0.isAvailable ? $0.session?.remainingPercent : nil, tint: Theme.brand(for: $0.id),
                      dim: focus.isDimmed($0.id) ? 1 : 0)
        }
        let inner = OrbitRings.innerRadius(ringCount: rings.count, size: Self.chartSize)
        let shown = focus.tool.flatMap { id in providers.first { $0.id == id } }
        return ZStack {
            OrbitRings(rings: rings)
            OrbitCentre(usage: shown ?? lowest, isFocused: shown != nil).frame(width: inner * 2 - 6)
        }
        .frame(width: Self.chartSize, height: Self.chartSize)
        .contentShape(Rectangle())
        .onContinuousHover { phase in point(phase) }
        .pointingHand(isEnabled: pointedRing != nil && interaction.open != nil)
        .onTapGesture(coordinateSpace: .local) { location in
            if let id = ring(at: location), let open = interaction.open { open(id) }
        }
        .animation(ToolFocus.motion, value: focus.tool)
    }

    private func ring(at location: CGPoint) -> String? {
        OrbitRings.ringIndex(at: location, size: Self.chartSize, ringCount: ringedProviders.count).map { ringedProviders[$0].id }
    }

    /// Moves the focus to the ring under the pointer, and off it when the pointer leaves the rings.
    private func point(_ phase: HoverPhase) {
        var target: String?
        if case .active(let location) = phase { target = ring(at: location) }
        guard target != pointedRing else { return }
        if let pointedRing { focus.update(pointedRing, false) }
        if let target { focus.update(target, true) }
        pointedRing = target
    }

    /// The tool with the least left in its short window.
    private var lowest: ProviderUsage? {
        providers.filter { $0.isAvailable && $0.session != nil }
            .min { ($0.session?.remainingPercent ?? 0) < ($1.session?.remainingPercent ?? 0) }
    }
}

/// The share in the middle and whose it is: the focused tool's, else the lowest.
private struct OrbitCentre: View {
    private static let figureSize: CGFloat = 24

    let usage: ProviderUsage?
    let isFocused: Bool

    @Environment(\.panelStyle) private var style

    var body: some View {
        VStack(spacing: 3) {
            PercentFigure(window: usage?.session, size: Self.figureSize)
            Text(usage.map { isFocused ? $0.title : "최저 · \($0.title)" } ?? "연결 안 됨")
                .font(Theme.label(TypeScale.micro, .medium, style: style))
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
    @Environment(\.toolFocus) private var focus

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                heading("단기", width: Self.shortWidth)
                heading("장기", width: Self.longWidth)
                heading("초기화", width: Self.countdownWidth)
            }
            .frame(height: 14)
            ForEach(Array(providers.enumerated()), id: \.element.id) { index, usage in
                row(usage, index: index).toolMark(usage.id)
            }
            revealedTimes
        }
        .frame(maxWidth: .infinity)
    }

    /// The focused tool's reset and measuring times, in a line the legend always keeps free.
    private var revealedTimes: some View {
        let shown = focus.tool.flatMap { id in providers.first { $0.id == id && $0.isAvailable } }
        return Text(shown.map { HoverDetail.line(for: $0) } ?? " ")
            .font(Theme.figure(TypeScale.caption, .regular, style: style))
            .foregroundStyle(Theme.mutedText)
            .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .trailing)
            .animation(ToolFocus.motion, value: focus.tool)
    }

    private func heading(_ text: String, width: CGFloat) -> some View {
        Text(text).font(Theme.label(TypeScale.micro, .medium, style: style)).foregroundStyle(Theme.faintText)
            .frame(width: width, alignment: .trailing)
    }

    private func row(_ usage: ProviderUsage, index: Int) -> some View {
        HStack(spacing: 0) {
            ProviderName(usage: usage, index: index, tint: Theme.brand(for: usage.id))
            Spacer(minLength: 4)
            if usage.isAvailable {
                Text(percentText(usage.session))
                    .font(Theme.figure(TypeScale.body, .semibold, style: style))
                    .foregroundStyle(usage.session.flatMap { Theme.alert($0.remainingPercent) } ?? Theme.primaryText)
                    .frame(width: Self.shortWidth, alignment: .trailing)
                Text(percentText(usage.weekly))
                    .font(Theme.figure(TypeScale.caption, .regular, style: style))
                    .foregroundStyle(usage.weekly.flatMap { Theme.alert($0.remainingPercent) } ?? Theme.mutedText)
                    .frame(width: Self.longWidth, alignment: .trailing)
                Text(countdown(until: usage.session?.resetsAt, now: now, style: style))
                    .font(Theme.figure(TypeScale.caption, .regular, style: style))
                    .foregroundStyle(Theme.faintText)
                    .frame(width: Self.countdownWidth, alignment: .trailing)
            } else {
                Text("연결 안 됨").font(Theme.label(TypeScale.caption, .medium, style: style)).foregroundStyle(Theme.faintText)
            }
        }
        .frame(height: Self.rowHeight)
    }

}
