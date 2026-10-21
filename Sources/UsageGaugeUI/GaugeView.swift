import SwiftUI
import UsageGaugeCore

/// Panel content: a wide, low grid of providers. Each puts the dial for the short window beside
/// its reset time and a bar for the long one, so the panel grows sideways instead of crowding the
/// dial. The style picks the drawing; the mono style also sets every block in a hairline grid.
public struct GaugeView: View {
    public static let cardsPerRow = 2
    private static let rowSpacing: CGFloat = 10
    private static let columnSpacing: CGFloat = 24

    let providers: [ProviderUsage]
    let status: String
    let now: Date
    let onClose: (() -> Void)?
    let opacity: Binding<Double>?
    let opacityRange: ClosedRange<Double>
    let style: PanelStyle
    let frozenAt: TimeInterval?

    @State private var isAdjustingOpacity = false

    /// - Parameters:
    ///   - opacity: whole-panel opacity; when given, the header gets a control to adjust it.
    ///   - frozenAt: fixed animation time for still renders; nil animates.
    public init(providers: [ProviderUsage], status: String, now: Date,
                onClose: (() -> Void)? = nil, opacity: Binding<Double>? = nil,
                opacityRange: ClosedRange<Double> = 0.3...1.0, style: PanelStyle = .mono,
                frozenAt: TimeInterval? = nil) {
        self.providers = providers
        self.status = status
        self.now = now
        self.onClose = onClose
        self.opacity = opacity
        self.opacityRange = opacityRange
        self.style = style
        self.frozenAt = frozenAt
    }

    public var body: some View {
        Group {
            if style == .mono { gridLayout } else { flowLayout }
        }
        .foregroundStyle(Theme.primaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .fixedSize()
        .environment(\.panelStyle, style)
    }

    private var flowLayout: some View {
        VStack(spacing: Self.rowSpacing) {
            header.modifier(WindowDragArea())
            opacityControl
            emptyNote
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: Self.columnSpacing) {
                    ForEach(row, id: \.usage.id) { card($0) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(WindowDragArea())
            }
        }
        .padding(Theme.panelPadding)
    }

    /// Mono: header and providers each sit in a cell of a hairline grid that runs edge to edge.
    private var gridLayout: some View {
        VStack(spacing: 0) {
            VStack(spacing: Self.rowSpacing) {
                header.modifier(WindowDragArea())
                opacityControl
            }
            .padding(.horizontal, Theme.panelPadding)
            .padding(.vertical, 10)
            emptyNote
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRule(isVertical: false)
                HStack(spacing: 0) {
                    ForEach(row, id: \.usage.id) { entry in
                        if entry.index % Self.cardsPerRow > 0 { GridRule(isVertical: true) }
                        card(entry).padding(Theme.panelPadding)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(WindowDragArea())
            }
        }
    }

    private func card(_ entry: (index: Int, usage: ProviderUsage)) -> some View {
        ProviderCard(usage: entry.usage, index: entry.index, now: now, frozenAt: frozenAt)
    }

    @ViewBuilder
    private var opacityControl: some View {
        if isAdjustingOpacity, let opacity {
            OpacityControl(value: opacity, range: opacityRange)
        }
    }

    @ViewBuilder
    private var emptyNote: some View {
        if providers.isEmpty {
            Text("CodexBar에서 켠 서비스가 없어요")
                .font(Theme.label(12, style: style))
                .foregroundStyle(Theme.mutedText)
                .frame(height: Theme.dialSize)
                .padding(.horizontal, Theme.panelPadding)
        }
    }

    private var rows: [[(index: Int, usage: ProviderUsage)]] {
        let entries = providers.enumerated().map { (index: $0.offset, usage: $0.element) }
        return stride(from: 0, to: entries.count, by: Self.cardsPerRow).map {
            Array(entries[$0..<min($0 + Self.cardsPerRow, entries.count)])
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if style == .dot {
                Circle().fill(Theme.signal).frame(width: 5, height: 5)
            }
            Text("남은 사용량")
                .font(Theme.label(10, .semibold, style: style))
                .tracking(0.6)
                .foregroundStyle(Theme.faintText)
            Spacer(minLength: 16)
            Text(status).font(Theme.figure(10, .regular, style: style)).foregroundStyle(Theme.faintText)
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

/// One-point line of the mono style's grid.
private struct GridRule: View {
    let isVertical: Bool

    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: isVertical ? 1 : nil, height: isVertical ? nil : 1)
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

/// Bare glyph that brightens under the pointer; a faint disc (a square in the mono style) marks
/// it while its control is open.
private struct HeaderButton: View {
    let symbol: String
    let help: String
    var isOn = false
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.panelStyle) private var style

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: style == .mono ? 3 : 10, style: .continuous)
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isOn || isHovered ? Theme.primaryText : Theme.faintText)
                .frame(width: 20, height: 20)
                .background(shape.fill(.white.opacity(isOn ? 0.12 : isHovered ? 0.07 : 0)))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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
