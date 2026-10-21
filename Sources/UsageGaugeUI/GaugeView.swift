import SwiftUI
import UsageGaugeCore

/// Panel content: a wide, low grid of provider cards. Each card puts the iris dial for the short
/// window beside its reset time and a light-streak bar for the long one, so the panel grows
/// sideways instead of crowding the dial.
public struct GaugeView: View {
    public static let cardsPerRow = 2

    let providers: [ProviderUsage]
    let status: String
    let now: Date
    let onClose: (() -> Void)?
    let opacity: Binding<Double>?
    let opacityRange: ClosedRange<Double>
    let frozenAt: TimeInterval?

    @State private var isAdjustingOpacity = false

    /// - Parameters:
    ///   - opacity: whole-panel opacity; when given, the header gets a control to adjust it.
    ///   - frozenAt: fixed animation time for still renders; nil animates.
    public init(providers: [ProviderUsage], status: String, now: Date,
                onClose: (() -> Void)? = nil, opacity: Binding<Double>? = nil,
                opacityRange: ClosedRange<Double> = 0.3...1.0, frozenAt: TimeInterval? = nil) {
        self.providers = providers
        self.status = status
        self.now = now
        self.onClose = onClose
        self.opacity = opacity
        self.opacityRange = opacityRange
        self.frozenAt = frozenAt
    }

    public var body: some View {
        VStack(spacing: 8) {
            header.modifier(WindowDragArea())
            if isAdjustingOpacity, let opacity {
                OpacityControl(value: opacity, range: opacityRange)
            }
            if providers.isEmpty {
                Text("CodexBar에서 켠 서비스가 없어요")
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.mutedText)
                    .frame(height: Theme.dialSize)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                if rowIndex > 0 { HorizontalHairline() }
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { index, usage in
                        if index > 0 { VerticalHairline() }
                        ProviderCard(usage: usage, now: now, frozenAt: frozenAt)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(WindowDragArea())
            }
        }
        .padding(Theme.panelPadding)
        .foregroundStyle(Theme.primaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .fixedSize()
    }

    private var rows: [[ProviderUsage]] {
        stride(from: 0, to: providers.count, by: Self.cardsPerRow).map {
            Array(providers[$0..<min($0 + Self.cardsPerRow, providers.count)])
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("남은 사용량")
                .font(Theme.font(10, .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.mutedText)
            Spacer(minLength: 16)
            Text(status).font(Theme.number(10, .regular)).foregroundStyle(Theme.faintText)
            if opacity != nil {
                HeaderButton(symbol: "circle.lefthalf.filled", help: "투명도", isOn: isAdjustingOpacity) {
                    withAnimation(.easeOut(duration: 0.2)) { isAdjustingOpacity.toggle() }
                }
            }
            if let onClose {
                HeaderButton(symbol: "xmark", help: "숨기기 (⌥⌘U)", action: onClose)
            }
        }
    }
}

/// Dragging here moves the window (macOS 15+). Applied to the header and grid only, so the
/// opacity bar's drag is never taken over.
private struct WindowDragArea: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.contentShape(Rectangle()).gesture(WindowDragGesture())
        } else {
            content
        }
    }
}

private struct HeaderButton: View {
    let symbol: String
    let help: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isOn ? Theme.primaryText : Theme.mutedText)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.white.opacity(isOn ? 0.16 : 0.06)))
                .overlay(Circle().strokeBorder(GlassEdge.gradient, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Slider for the whole panel's opacity, shown under the header while adjusting.
private struct OpacityControl: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack(spacing: 10) {
            Text("투명도").font(Theme.font(10, .medium)).foregroundStyle(Theme.mutedText)
            OpacityBar(value: $value, range: range)
                .frame(height: 20)
            Text("\(Int((value * 100).rounded()))%")
                .font(Theme.number(10))
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.05)))
        .overlay(Capsule().strokeBorder(GlassEdge.gradient, lineWidth: 0.8))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

/// One provider: the dial on the left, reset time and the long window on the right.
private struct ProviderCard: View {
    let usage: ProviderUsage
    let now: Date
    let frozenAt: TimeInterval?

    var body: some View {
        let tint = Theme.brand(for: usage.id)
        HStack(spacing: 12) {
            SessionGauge(window: usage.isAvailable ? usage.session : nil, tint: tint, size: Theme.dialSize,
                         now: now, showsLabel: false, frozenAt: frozenAt)
            VStack(alignment: .leading, spacing: 0) {
                titleRow
                if usage.isAvailable {
                    Text(sessionLine)
                        .font(Theme.number(10, .regular))
                        .foregroundStyle(Theme.mutedText)
                        .padding(.top, 3)
                    Spacer(minLength: 6)
                    LongWindowBar(window: usage.weekly, tint: tint, now: now, frozenAt: frozenAt)
                } else {
                    Text("연결 안 됨")
                        .font(Theme.font(11, .semibold))
                        .foregroundStyle(Theme.mutedText)
                        .padding(.top, 6)
                    Text(usage.errorMessage ?? "CodexBar 로그인을 확인하세요")
                        .font(Theme.font(10))
                        .foregroundStyle(Theme.faintText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                    Spacer(minLength: 0)
                }
            }
            .frame(width: Theme.detailWidth, height: Theme.dialSize, alignment: .topLeading)
        }
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            Text(usage.title).font(Theme.font(13, .bold))
            Spacer(minLength: 4)
            if let plan = usage.plan {
                Text(plan.uppercased())
                    .font(Theme.font(8, .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.mutedText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.white.opacity(0.06)))
                    .overlay(Capsule().strokeBorder(GlassEdge.gradient, lineWidth: 0.8))
            }
        }
    }

    /// "5시간 · 3시간 50분 후 초기화": which window the dial shows and when it resets.
    private var sessionLine: String {
        let label = usage.session?.label ?? "단기"
        return "\(label) · \(ResetCountdown.text(until: usage.session?.resetsAt, now: now)) 후 초기화"
    }
}

/// Iris dial + remaining percent for one window. The figure sits in the pupil, lit from below
/// by the tool's colour.
public struct SessionGauge: View {
    /// Widest the figure may run, as a share of the dial, so "100%" stays inside the pupil.
    private static let pupilTextWidth: CGFloat = 0.52

    let window: UsageWindow?
    let tint: Color
    let size: CGFloat
    let now: Date
    let showsLabel: Bool
    let frozenAt: TimeInterval?

    /// - Parameter showsLabel: names the window ("5시간") under the figure; off when the caller
    ///   names it beside the dial, which leaves the pupil to the figure alone.
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
        let color = Theme.status(remaining, brand: tint)
        ZStack {
            IrisDial(remainingPercent: remaining, elapsedFraction: window?.elapsedFraction(now: now),
                      color: color, frozenAt: frozenAt)
            VStack(spacing: size * 0.01) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    figure(window.map { "\($0.displayPercent)" } ?? ResetCountdown.unknown, color: color)
                    if window != nil {
                        Text("%").font(Theme.font(size * 0.1, .medium)).foregroundStyle(Theme.mutedText)
                    }
                }
                if showsLabel {
                    Text(window?.label ?? "단기")
                        .font(Theme.font(size * 0.105, .medium))
                        .tracking(size * 0.004)
                        .foregroundStyle(Theme.faintText)
                }
            }
            .frame(maxWidth: size * Self.pupilTextWidth)
            .minimumScaleFactor(0.7)
        }
        .frame(width: size, height: size)
    }

    private func figure(_ text: String, color: Color) -> some View {
        let type = Text(text).font(Theme.display(size * (showsLabel ? 0.27 : 0.3))).tracking(-size * 0.006)
        return type
            .foregroundStyle(LinearGradient(stops: [
                .init(color: .white, location: 0.4),
                .init(color: color, location: 1.15),
            ], startPoint: .top, endPoint: .bottom))
            .background(type.foregroundStyle(color).blur(radius: size * 0.05).opacity(0.55).offset(y: size * 0.02))
    }
}

/// The long window (weekly, monthly) as a light-streak bar with its share and reset time.
private struct LongWindowBar: View {
    let window: UsageWindow?
    let tint: Color
    let now: Date
    let frozenAt: TimeInterval?

    var body: some View {
        let remaining = window?.remainingPercent ?? 0
        let color = Theme.status(remaining, brand: tint)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(window?.label ?? "장기").font(Theme.font(10, .medium)).foregroundStyle(Theme.mutedText)
                Spacer()
                Text(window.map { "\($0.displayPercent)%" } ?? ResetCountdown.unknown)
                    .font(Theme.number(11, .bold))
            }
            CometBar(remainingPercent: window == nil ? 0 : remaining, thickness: 4, color: color, frozenAt: frozenAt)
            Text("\(ResetCountdown.text(until: window?.resetsAt, now: now)) 후 초기화")
                .font(Theme.number(9, .regular))
                .foregroundStyle(Theme.faintText)
        }
    }
}

private struct VerticalHairline: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Theme.hairline, .clear], startPoint: .top, endPoint: .bottom))
            .frame(width: 1)
            .padding(.horizontal, 12)
    }
}

private struct HorizontalHairline: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Theme.hairline, .clear], startPoint: .leading, endPoint: .trailing))
            .frame(height: 1)
    }
}

/// Pill with a glass rim, used for labels.
public struct GlassChip<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.07)))
            .overlay(Capsule().strokeBorder(GlassEdge.gradient, lineWidth: 0.8))
    }
}

/// Thin rim that catches light on the top-left edge, as on frosted glass.
public enum GlassEdge {
    public static let gradient = LinearGradient(colors: [.white.opacity(0.34), .white.opacity(0.06), .white.opacity(0.14)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing)
}
