import SwiftUI
import UsageGaugeCore

/// One provider: the dial on the left, reset time and the long window on the right, drawn in the
/// panel's style.
struct ProviderCard: View {
    let usage: ProviderUsage
    /// Position in the panel, shown as "01", "02", … by the dot style.
    let index: Int
    let now: Date
    let frozenAt: TimeInterval?

    @Environment(\.panelStyle) private var style

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        HStack(spacing: 12) {
            SessionGauge(window: usage.isAvailable ? usage.session : nil, tint: tint, size: Theme.dialSize,
                         now: now, showsLabel: false, frozenAt: frozenAt)
            VStack(alignment: .leading, spacing: 0) {
                titleRow(tint: tint)
                if usage.isAvailable {
                    Text(sessionLine)
                        .font(Theme.figure(10, .regular, style: style))
                        .foregroundStyle(Theme.mutedText)
                        .padding(.top, 4)
                    Spacer(minLength: 6)
                    LongWindowBar(window: usage.weekly, tint: tint, now: now, frozenAt: frozenAt)
                } else {
                    Text("연결 안 됨")
                        .font(Theme.label(11, .semibold, style: style))
                        .foregroundStyle(Theme.mutedText)
                        .padding(.top, 6)
                    Text(usage.errorMessage ?? "CodexBar 로그인을 확인하세요")
                        .font(Theme.label(10, style: style))
                        .foregroundStyle(Theme.faintText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                    Spacer(minLength: 0)
                }
            }
            .frame(width: Theme.detailWidth, height: Theme.dialSize, alignment: .topLeading)
        }
        .background(alignment: .leading) {
            if style == .iris { DialGlow(tint: tint) }
        }
    }

    private func titleRow(tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            ProviderName(usage: usage, index: index, tint: tint)
            PlanTag(plan: usage.plan)
        }
    }

    /// "5시간 · 3시간 50분 후 초기화" (or "3h 50m" in the monospaced styles): which window the
    /// dial shows and when it resets.
    private var sessionLine: String {
        let label = usage.session?.label ?? "단기"
        return "\(label) · \(countdown(until: usage.session?.resetsAt, now: now, style: style)) 후 초기화"
    }
}

/// The countdown in the style's voice: words for iris, terse units for dot and mono.
func countdown(until date: Date?, now: Date, style: PanelStyle) -> String {
    style.isMonospaced ? ResetCountdown.compact(until: date, now: now) : ResetCountdown.text(until: date, now: now)
}

/// Dial + remaining percent for one window, drawn in the panel's style. The figure sits in the
/// middle and turns to the warning colours as the window runs low; the dial keeps the tool's colour.
public struct SessionGauge: View {
    /// Widest the figure may run, as a share of the dial, so "100%" stays inside the ring.
    private static let pupilTextWidth: CGFloat = 0.52

    let window: UsageWindow?
    let tint: Color
    let size: CGFloat
    let now: Date
    let showsLabel: Bool
    let frozenAt: TimeInterval?

    @Environment(\.panelStyle) private var style

    /// - Parameter showsLabel: names the window ("5시간") under the figure; off when the caller
    ///   names it beside the dial, which leaves the middle to the figure alone.
    public init(window: UsageWindow?, tint: Color, size: CGFloat, now: Date = Date(), showsLabel: Bool = true,
                frozenAt: TimeInterval? = nil) {
        self.window = window
        self.tint = tint
        self.size = size
        self.now = now
        self.showsLabel = showsLabel
        self.frozenAt = frozenAt
    }

    public var body: some View {
        let remaining = window?.remainingPercent ?? 0
        let elapsed = window?.elapsedFraction(now: now)
        let alert = window.flatMap { Theme.alert($0.remainingPercent) }
        ZStack {
            switch style {
            case .iris: IrisDial(remainingPercent: remaining, elapsedFraction: elapsed, color: tint, frozenAt: frozenAt)
            case .dot: DotDial(remainingPercent: remaining, elapsedFraction: elapsed, color: tint, frozenAt: frozenAt)
            case .mono: TickDial(remainingPercent: remaining, elapsedFraction: elapsed, color: tint, frozenAt: frozenAt)
            }
            VStack(spacing: size * (style == .dot ? 0.05 : 0.01)) {
                readout(alert: alert)
                if showsLabel {
                    Text(window?.label ?? "단기")
                        .font(Theme.label(size * 0.105, .medium, style: style))
                        .tracking(size * 0.004)
                        .foregroundStyle(Theme.faintText)
                }
            }
            .frame(maxWidth: size * Self.pupilTextWidth)
            .minimumScaleFactor(0.7)
        }
        .frame(width: size, height: size)
    }

    private var figureText: String {
        window.map { "\($0.displayPercent)" } ?? ResetCountdown.unknown
    }

    @ViewBuilder
    private func readout(alert: Color?) -> some View {
        switch style {
        case .iris:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                irisFigure(color: alert ?? tint)
                percentSign(Theme.font(size * (showsLabel ? 0.1 : 0.085), .medium))
            }
        case .dot:
            // Three digits get a finer grid so "100%" still fits inside the clock ring.
            let pitch = size * (figureText.count > 2 ? 0.026 : 0.034)
            HStack(alignment: .bottom, spacing: pitch) {
                DotMatrixText(figureText, pitch: pitch, color: alert ?? .white)
                if window != nil { DotMatrixText("%", pitch: pitch * 0.55, color: Theme.mutedText) }
            }
        case .mono:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(figureText).font(Theme.mono(size * 0.22, .semibold)).foregroundStyle(alert ?? .white)
                percentSign(Theme.mono(size * 0.09, .medium))
            }
        }
    }

    @ViewBuilder
    private func percentSign(_ font: Font) -> some View {
        if window != nil { Text("%").font(font).foregroundStyle(Theme.mutedText) }
    }

    /// Lit from below by the tool's colour (or the warning colour when low).
    private func irisFigure(color: Color) -> some View {
        let type = Text(figureText).font(Theme.display(size * (showsLabel ? 0.27 : 0.22))).tracking(-size * 0.004)
        return type
            .foregroundStyle(LinearGradient(stops: [
                .init(color: .white, location: 0.4),
                .init(color: color, location: 1.15),
            ], startPoint: .top, endPoint: .bottom))
            .background(type.foregroundStyle(color).blur(radius: size * 0.05).opacity(0.55).offset(y: size * 0.02))
    }
}

/// The long window (weekly, monthly): label, share and reset time over a bar in the tool's colour —
/// a light streak, a strip of dots or a row of segments, by style.
struct LongWindowBar: View {
    let window: UsageWindow?
    let tint: Color
    let now: Date
    let frozenAt: TimeInterval?

    @Environment(\.panelStyle) private var style

    var body: some View {
        let remaining = window == nil ? 0 : window?.remainingPercent ?? 0
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(window?.label ?? "장기").font(Theme.label(10, .medium, style: style)).foregroundStyle(Theme.mutedText)
                Text(window.map { "\($0.displayPercent)%" } ?? ResetCountdown.unknown)
                    .font(Theme.figure(11, .semibold, style: style))
                    .foregroundStyle(Theme.alert(remaining) ?? Theme.primaryText)
                Spacer(minLength: 6)
                Text(style.isMonospaced ? countdown(until: window?.resetsAt, now: now, style: style)
                                        : "\(countdown(until: window?.resetsAt, now: now, style: style)) 후")
                    .font(Theme.figure(9.5, .regular, style: style))
                    .foregroundStyle(Theme.faintText)
            }
            WindowBar(remainingPercent: remaining, tint: tint, frozenAt: frozenAt)
        }
    }
}

/// The tool's colour glowing through the glass from behind the dial. It fades out within the
/// panel's padding, so it never spills past the glass.
private struct DialGlow: View {
    let tint: Color

    private static let opacity = 0.28
    private static let reach = 0.7

    var body: some View {
        let dial = Theme.dialSize
        RadialGradient(colors: [tint.opacity(Self.opacity), tint.opacity(0)], center: .center,
                       startRadius: dial * 0.3, endRadius: dial * Self.reach)
            .frame(width: dial * Self.reach * 2, height: dial * Self.reach * 2)
            .offset(x: dial / 2 - dial * Self.reach)
            .allowsHitTesting(false)
    }
}

/// The tool's name in the style's voice: a brand square (mono), "01" numbering (dot) or plain type
/// (iris, which can take a small brand dot where the name stands alone under a chart).
struct ProviderName: View {
    let usage: ProviderUsage
    /// Position in the panel, shown as "01", "02", … by the dot style.
    let index: Int
    let tint: Color
    var marksBrand = false

    @Environment(\.panelStyle) private var style

    var body: some View {
        switch style {
        case .iris:
            HStack(spacing: 5) {
                if marksBrand { Circle().fill(tint).frame(width: 6, height: 6) }
                Text(usage.title).font(Theme.font(13, .semibold))
            }
        case .dot:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%02d", index + 1)).font(Theme.mono(9, .medium)).foregroundStyle(Theme.faintText)
                Text(usage.title.uppercased()).font(Theme.mono(11.5, .semibold)).tracking(0.6)
            }
        case .mono:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Rectangle().fill(tint).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[.bottom] }
                Text(usage.title.uppercased()).font(Theme.mono(11.5, .semibold)).tracking(0.6)
            }
        }
    }
}

/// The subscription plan in small caps beside a tool's name; nothing when the plan is unknown.
struct PlanTag: View {
    let plan: String?

    @Environment(\.panelStyle) private var style

    var body: some View {
        if let plan {
            Text(plan.uppercased())
                .font(Theme.label(8.5, .semibold, style: style))
                .tracking(0.9)
                .foregroundStyle(Theme.faintText)
        }
    }
}

/// The remaining share as the style's horizontal bar: a light streak, a strip of dots or a row of
/// ticks, in the tool's colour.
struct WindowBar: View {
    let remainingPercent: Double
    let tint: Color
    let frozenAt: TimeInterval?

    @Environment(\.panelStyle) private var style

    var body: some View {
        switch style {
        case .iris: CometBar(remainingPercent: remainingPercent, thickness: 3, color: tint, frozenAt: frozenAt)
        case .dot: DotBar(remainingPercent: remainingPercent, color: tint)
        case .mono: TickBar(remainingPercent: remainingPercent, color: tint)
        }
    }
}

/// "37%", or a dash for a window the tool does not report.
func percentText(_ window: UsageWindow?) -> String {
    window.map { "\($0.displayPercent)%" } ?? ResetCountdown.unknown
}
