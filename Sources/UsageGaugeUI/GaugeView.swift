import SwiftUI
import UsageGaugeCore

/// Panel content: a grid of providers, each with an iris dial for the short window and a glass
/// pill for the long one.
public struct GaugeView: View {
    public static let columnsPerRow = 3

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
        VStack(spacing: 14) {
            header.modifier(WindowDragArea())
            if isAdjustingOpacity, let opacity {
                OpacityControl(value: opacity, range: opacityRange)
            }
            if providers.isEmpty {
                Text("CodexBar에서 켠 서비스가 없어요")
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.mutedText)
                    .frame(width: Theme.columnWidth, height: 120)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                if rowIndex > 0 { HorizontalHairline() }
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { index, usage in
                        if index > 0 { VerticalHairline() }
                        ProviderColumn(usage: usage, now: now, frozenAt: frozenAt)
                    }
                }
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
        stride(from: 0, to: providers.count, by: Self.columnsPerRow).map {
            Array(providers[$0..<min($0 + Self.columnsPerRow, providers.count)])
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("남은 사용량")
                .font(Theme.font(11, .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.mutedText)
            Spacer(minLength: 24)
            Text(status).font(Theme.number(11, .regular)).foregroundStyle(Theme.faintText)
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
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isOn ? Theme.primaryText : Theme.mutedText)
                .frame(width: 26, height: 26)
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
        HStack(spacing: 12) {
            Text("투명도").font(Theme.font(11, .medium)).foregroundStyle(Theme.mutedText)
            OpacityBar(value: $value, range: range)
                .frame(height: 22)
            Text("\(Int((value * 100).rounded()))%")
                .font(Theme.number(11))
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.05)))
        .overlay(Capsule().strokeBorder(GlassEdge.gradient, lineWidth: 0.8))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

private struct ProviderColumn: View {
    let usage: ProviderUsage
    let now: Date
    let frozenAt: TimeInterval?

    private let ringSize: CGFloat = 94

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(usage.title).font(Theme.font(13, .bold))
                Spacer()
                if let plan = usage.plan {
                    Text(plan.uppercased())
                        .font(Theme.font(9, .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.mutedText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.06)))
                        .overlay(Capsule().strokeBorder(GlassEdge.gradient, lineWidth: 0.8))
                }
            }
            if usage.isAvailable {
                SessionGauge(window: usage.session, tint: Theme.brand(for: usage.id), size: ringSize, now: now, frozenAt: frozenAt)
                Text("\(ResetCountdown.text(until: usage.session?.resetsAt, now: now)) 후 초기화")
                    .font(Theme.number(11, .regular))
                    .foregroundStyle(Theme.mutedText)
                WindowPill(window: usage.weekly, tint: Theme.brand(for: usage.id), now: now, frozenAt: frozenAt)
            } else {
                VStack(spacing: 6) {
                    Text("연결 안 됨").font(Theme.font(13, .semibold)).foregroundStyle(Theme.mutedText)
                    Text(usage.errorMessage ?? "CodexBar 로그인을 확인하세요")
                        .font(Theme.font(11))
                        .foregroundStyle(Theme.faintText)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .frame(height: ringSize)
            }
        }
        .frame(width: Theme.columnWidth)
    }
}

/// Iris dial + remaining percent for one window. The figure sits in the pupil, lit from below
/// by the tool's colour.
public struct SessionGauge: View {
    let window: UsageWindow?
    let tint: Color
    let size: CGFloat
    let now: Date
    let frozenAt: TimeInterval?

    public init(window: UsageWindow?, tint: Color, size: CGFloat, now: Date = Date(), frozenAt: TimeInterval? = nil) {
        self.window = window
        self.tint = tint
        self.size = size
        self.now = now
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
                    Text("%").font(Theme.font(size * 0.075, .medium)).foregroundStyle(Theme.mutedText)
                }
                Text(window?.label ?? "단기")
                    .font(Theme.font(size * 0.07, .medium))
                    .tracking(size * 0.004)
                    .foregroundStyle(Theme.faintText)
            }
        }
        .frame(width: size, height: size)
    }

    private func figure(_ text: String, color: Color) -> some View {
        let type = Text(text).font(Theme.display(size * 0.22)).tracking(-size * 0.006)
        return type
            .foregroundStyle(LinearGradient(stops: [
                .init(color: .white, location: 0.4),
                .init(color: color, location: 1.15),
            ], startPoint: .top, endPoint: .bottom))
            .background(type.foregroundStyle(color).blur(radius: size * 0.05).opacity(0.55).offset(y: size * 0.02))
    }
}

private struct WindowPill: View {
    let window: UsageWindow?
    let tint: Color
    let now: Date
    let frozenAt: TimeInterval?

    var body: some View {
        let remaining = window?.remainingPercent ?? 0
        let color = Theme.status(remaining, brand: tint)
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(window?.label ?? "장기").font(Theme.font(11, .medium)).foregroundStyle(Theme.mutedText)
                Spacer()
                Text(window.map { "\($0.displayPercent)%" } ?? ResetCountdown.unknown)
                    .font(Theme.number(13, .bold))
            }
            CometBar(remainingPercent: window == nil ? 0 : remaining, thickness: 4, color: color, frozenAt: frozenAt)
            HStack {
                Text("초기화").font(Theme.font(10)).foregroundStyle(Theme.faintText)
                Spacer()
                Text(ResetCountdown.text(until: window?.resetsAt, now: now))
                    .font(Theme.number(10, .regular))
                    .foregroundStyle(Theme.faintText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(GlassEdge.gradient, lineWidth: 0.8))
    }
}

private struct VerticalHairline: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Theme.hairline, .clear], startPoint: .top, endPoint: .bottom))
            .frame(width: 1)
            .padding(.horizontal, 14)
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
