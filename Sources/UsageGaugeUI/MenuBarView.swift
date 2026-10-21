import SwiftUI
import UsageGaugeCore

/// Menu bar companion: per provider, name + 5-hour %, optionally with two stacked bars (5-hour
/// over weekly) between them. Bars and figures use the menu bar's own text colour until a window
/// runs low, so they stay legible on both light and dark wallpapers.
public struct MenuBarView: View {
    let providers: [ProviderUsage]
    let showsBars: Bool

    public init(providers: [ProviderUsage], showsBars: Bool = true) {
        self.providers = providers
        self.showsBars = showsBars
    }

    public var body: some View {
        HStack(spacing: 14) {
            ForEach(providers) { MenuBarItem(usage: $0, showsBars: showsBars) }
        }
        .padding(.horizontal, 8)
    }
}

private struct MenuBarItem: View {
    let usage: ProviderUsage
    let showsBars: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(usage.title).font(Theme.font(12, .semibold)).lineLimit(1).fixedSize()
            if showsBars {
                VStack(spacing: 3) {
                    MiniBar(window: usage.session)
                    MiniBar(window: usage.weekly)
                }
                .frame(width: 26)
            }
            Text(usage.session.map { "\($0.displayPercent)%" } ?? "–")
                .font(Theme.number(12, .semibold))
                .foregroundStyle(usage.session.flatMap { Theme.alert($0.remainingPercent) } ?? Color.primary)
                .lineLimit(1)
                .fixedSize()
        }
        .opacity(usage.isAvailable ? 1 : 0.5)
    }
}

private struct MiniBar: View {
    let window: UsageWindow?

    var body: some View {
        let remaining = window?.remainingPercent ?? 0
        let level = UsageLevel(remainingPercent: remaining)
        let color = level == .comfortable ? Color.primary : Theme.color(for: level)
        // Still, not pulsing: the status item redraws the whole strip, so animating it costs far more CPU.
        CometBar(remainingPercent: remaining, thickness: 3, color: color,
                 trackColor: Color.primary.opacity(0.25), headColor: color, isCompact: true, frozenAt: 0)
    }
}
