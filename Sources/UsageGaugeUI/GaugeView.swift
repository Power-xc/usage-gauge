import SwiftUI
import UsageGaugeCore

/// Panel content: a header over the providers, arranged by the layout (dials, bars, columns or
/// figures). The style picks the drawing; the mono style also sets every block in a hairline grid.
public struct GaugeView: View {
    let providers: [ProviderUsage]
    let status: String
    let now: Date
    let onClose: (() -> Void)?
    let opacity: Binding<Double>?
    let opacityRange: ClosedRange<Double>
    let scale: Binding<Double>?
    let scaleRange: ClosedRange<Double>
    let style: PanelStyle
    let layout: PanelLayout
    let history: UsageHistory
    let frozenAt: TimeInterval?

    let onLayout: ((PanelLayout) -> Void)?

    @State private var isAdjusting = false
    @State private var isPicking = false
    /// The tab the user picked; `hasPicked` tells "전체" from "not touched yet", so a still render
    /// can start on a preset tool (see `panelPreset`).
    @State private var pickedTool: String?
    @State private var hasPicked = false

    @Environment(\.panelPreset) private var preset
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - opacity: whole-panel opacity; when given, the header gets a control to adjust it.
    ///   - scale: whole-panel size factor; when given, the same control also offers a size bar. The
    ///     panel is scaled by the host (see `panelScale`), not by this view.
    ///   - frozenAt: fixed animation time for still renders; nil animates.
    ///   - onLayout: when given, the header gets a picker that switches the graph form; the host
    ///     applies the choice and passes the new `layout` back.
    public init(providers: [ProviderUsage], status: String, now: Date,
                onClose: (() -> Void)? = nil, opacity: Binding<Double>? = nil,
                opacityRange: ClosedRange<Double> = 0.3...1.0,
                scale: Binding<Double>? = nil, scaleRange: ClosedRange<Double> = 0.7...1.6,
                style: PanelStyle = .mono, layout: PanelLayout = .dial,
                history: UsageHistory = UsageHistory(),
                frozenAt: TimeInterval? = nil, onLayout: ((PanelLayout) -> Void)? = nil) {
        self.providers = providers
        self.status = status
        self.now = now
        self.onClose = onClose
        self.opacity = opacity
        self.opacityRange = opacityRange
        self.scale = scale
        self.scaleRange = scaleRange
        self.style = style
        self.layout = layout
        self.history = history
        self.frozenAt = frozenAt
        self.onLayout = onLayout
    }

    public var body: some View {
        Group {
            if style == .mono { gridLayout } else { flowLayout }
        }
        .foregroundStyle(Theme.primaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .fixedSize()
        .contentTransition(.numericText())
        .animation(valueMotion, value: providers)
        .animation(valueMotion, value: now)
        .environment(\.panelStyle, style)
        .environment(\.toolInteraction, ToolInteraction(open: showsTabs ? { open(tool: $0) } : nil))
    }

    private var flowLayout: some View {
        VStack(spacing: PanelLayout.blockSpacing) {
            header.modifier(WindowDragArea())
            layoutPicker
            opacityControl
            tabs
            emptyNote
            page
        }
        .padding(Theme.panelPadding)
    }

    /// Mono: header and providers each sit in a cell of a hairline grid that runs edge to edge.
    private var gridLayout: some View {
        VStack(spacing: 0) {
            VStack(spacing: PanelLayout.blockSpacing) {
                header.modifier(WindowDragArea())
                layoutPicker
                opacityControl
            }
            .padding(.horizontal, Theme.panelPadding)
            .padding(.vertical, 10)
            if showsTabs {
                GridRule(isVertical: false)
                tabs.padding(.horizontal, Theme.panelPadding).padding(.vertical, 4)
            }
            emptyNote
            page
        }
    }

    // MARK: Tabs and pages

    private var showsTabs: Bool { providers.count > 1 }

    /// The tool whose detail page is open; nil shows the layout. A tool that disappears falls back
    /// to the overview.
    private var selectedUsage: ProviderUsage? {
        guard showsTabs, let id = hasPicked ? pickedTool : preset.tool else { return nil }
        return providers.first { $0.id == id }
    }

    private func open(tool id: String?) {
        withAnimation(pageMotion) {
            pickedTool = id
            hasPicked = true
        }
    }

    @ViewBuilder
    private var tabs: some View {
        if showsTabs {
            PanelTabs(providers: providers, selection: selectedUsage?.id) { open(tool: $0) }
        }
    }

    /// The layout, or the selected tool's detail; changing either crossfades with a slight scale.
    private var page: some View {
        ZStack(alignment: .top) {
            Group {
                if let usage = selectedUsage { detail(usage) } else { content }
            }
            .modifier(WindowDragArea())
            .id("\(layout.rawValue)|\(style.rawValue)|\(selectedUsage?.id ?? "")")
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        }
        .animation(pageMotion, value: layout)
        .animation(pageMotion, value: style)
    }

    private func detail(_ usage: ProviderUsage) -> some View {
        VStack(spacing: 0) {
            if style == .mono { GridRule(isVertical: false) }
            ToolDetail(usage: usage, index: providers.firstIndex { $0.id == usage.id } ?? 0, now: now,
                       frozenAt: frozenAt) {
                // Further sections of the detail page (a history chart) go here.
            }
            .padding(style == .mono ? Theme.panelPadding : 0)
        }
    }

    private var pageMotion: Animation { .easeInOut(duration: reduceMotion ? 0.15 : 0.3) }
    private var valueMotion: Animation { .easeInOut(duration: reduceMotion ? 0.15 : 0.5) }

    @ViewBuilder
    private var content: some View {
        switch layout {
        case .dial: DialLayout(providers: providers, now: now, frozenAt: frozenAt)
        case .bars: BarsLayout(providers: providers, now: now, frozenAt: frozenAt)
        case .columns: ColumnsLayout(providers: providers, now: now, frozenAt: frozenAt)
        case .figures: FiguresLayout(providers: providers, now: now)
        case .orbit: OrbitLayout(providers: providers, now: now)
        case .capsule: CapsuleLayout(providers: providers, now: now, frozenAt: frozenAt)
        case .trend: TrendLayout(providers: providers, history: history, now: now)
        case .histogram: HistogramLayout(providers: providers, now: now, history: history)
        case .spark: SparkLayout(providers: providers, now: now, history: history, frozenAt: frozenAt)
        case .burst: BurstLayout(providers: providers, now: now, history: history)
        }
    }

    /// Graph forms to choose from, shown under the header while the picker is open.
    @ViewBuilder
    private var layoutPicker: some View {
        if isPicking, let onLayout {
            LayoutPicker(selection: layout, choose: onLayout)
        }
    }

    /// The opacity and size bars, shown under the header while adjusting.
    @ViewBuilder
    private var opacityControl: some View {
        if isAdjusting, opacity != nil || scale != nil {
            PanelControls(opacity: opacity, opacityRange: opacityRange, scale: scale, scaleRange: scaleRange)
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
            if onLayout != nil {
                HeaderButton(symbol: "square.grid.2x2", help: "그래프 모양", isOn: isPicking) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPicking.toggle()
                        isAdjusting = false
                    }
                }
            }
            if opacity != nil || scale != nil {
                HeaderButton(symbol: "slider.horizontal.3", help: "투명도 · 크기", isOn: isAdjusting) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isAdjusting.toggle()
                        isPicking = false
                    }
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
        .pointingHand()
        .help(help)
    }
}

/// Bars for the whole panel's opacity and size, in one capsule under the header while adjusting.
private struct PanelControls: View {
    let opacity: Binding<Double>?
    let opacityRange: ClosedRange<Double>
    let scale: Binding<Double>?
    let scaleRange: ClosedRange<Double>

    var body: some View {
        VStack(spacing: 2) {
            if let opacity { ControlRow(title: "투명도", value: opacity, range: opacityRange) }
            if let scale { ControlRow(title: "크기", value: scale, range: scaleRange) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(GlassEdge.gradient, lineWidth: 0.8))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

private struct ControlRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(Theme.font(10, .medium)).foregroundStyle(Theme.mutedText)
                .frame(width: 34, alignment: .leading)
            ValueBar(value: $value, range: range)
                .frame(height: 20)
            Text("\(Int((value * 100).rounded()))%")
                .font(Theme.number(10))
                .frame(width: 36, alignment: .trailing)
        }
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
