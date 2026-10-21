import SwiftUI
import UsageGaugeCore

/// "전체" plus one tab per tool, with a short underline in the selected tool's colour (white for
/// the overview). With many tools the names shorten, then drop, so the row never wraps.
struct PanelTabs: View {
    /// Approximate advance of one character at the tab type size, per style family.
    private static let monoAdvance: CGFloat = 7
    private static let proportionalAdvance: CGFloat = 6.4
    private static let tabChrome: CGFloat = 26
    private static let shortNameLength = 4

    let providers: [ProviderUsage]
    /// The selected tool's id; nil is the overview.
    let selection: String?
    let select: (String?) -> Void

    @Environment(\.panelStyle) private var style
    @Namespace private var underline

    var body: some View {
        HStack(spacing: 0) {
            tab(id: nil, title: "전체", tint: .white, mark: nil)
            ForEach(Array(providers.enumerated()), id: \.element.id) { index, usage in
                tab(id: usage.id, title: name(of: usage), tint: Theme.brand(for: usage.id), mark: mark(index))
            }
        }
        .frame(width: PanelLayout.contentWidth)
    }

    private enum Density { case full, short, marksOnly }

    private var density: Density {
        let advance = style.isMonospaced ? Self.monoAdvance : Self.proportionalAdvance
        func fits(_ length: (ProviderUsage) -> Int) -> Bool {
            let letters = providers.map(length).reduce(2, +)
            return CGFloat(letters) * advance + CGFloat(providers.count + 1) * Self.tabChrome <= PanelLayout.contentWidth
        }
        if fits({ $0.title.count }) { return .full }
        return fits({ min($0.title.count, Self.shortNameLength) }) ? .short : .marksOnly
    }

    private func name(of usage: ProviderUsage) -> String {
        switch density {
        case .full: usage.title
        case .short: String(usage.title.prefix(Self.shortNameLength))
        case .marksOnly: ""
        }
    }

    /// Dot numbers its tools "01"…; the other styles use a small brand mark.
    private func mark(_ index: Int) -> TabMark { style == .dot ? .number(index + 1) : .brand }

    private func tab(id: String?, title: String, tint: Color, mark: TabMark?) -> some View {
        PanelTab(title: title, tint: tint, mark: mark, isSelected: id == selection, underline: underline) {
            select(id)
        }
    }
}

enum TabMark {
    case brand
    case number(Int)
}

private struct PanelTab: View {
    private static let underlineWidth: CGFloat = 18

    let title: String
    let tint: Color
    let mark: TabMark?
    let isSelected: Bool
    let underline: Namespace.ID
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.panelStyle) private var style

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    markView
                    if !title.isEmpty {
                        Text(style.isMonospaced ? title.uppercased() : title)
                            .font(Theme.label(11, isSelected ? .semibold : .medium, style: style))
                            .tracking(style.isMonospaced ? 0.6 : 0)
                    }
                }
                .foregroundStyle(isSelected || isHovered ? Theme.primaryText : Theme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                ZStack {
                    Color.clear.frame(height: 2)
                    if isSelected { underlineBar.matchedGeometryEffect(id: "selection", in: underline) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointingHand()
    }

    @ViewBuilder
    private var markView: some View {
        switch mark {
        case .brand:
            if style == .mono {
                Rectangle().fill(tint).frame(width: 6, height: 6)
            } else {
                Circle().fill(tint).frame(width: 6, height: 6)
            }
        case .number(let number):
            Text(String(format: "%02d", number)).font(Theme.mono(9, .medium)).foregroundStyle(Theme.faintText)
        case nil:
            EmptyView()
        }
    }

    /// Iris lets the underline glow; dot and mono keep it a clean line.
    private var underlineBar: some View {
        Capsule()
            .fill(tint)
            .frame(width: Self.underlineWidth, height: style == .mono ? 1.5 : 2)
            .shadow(color: style == .iris ? tint.opacity(0.9) : .clear, radius: 4)
    }
}
