import SwiftUI
import UsageGaugeCore

/// "전체" plus one tab per tool, with a short underline in the selected tool's colour (white for
/// the overview). The row shows full names while they fit, then short names, then marks only,
/// spaced evenly with a minimum gap, so tabs never run into each other.
struct PanelTabs: View {
    private static let shortNameLength = 4
    private static let minimumGap: CGFloat = 12

    let providers: [ProviderUsage]
    /// The selected tool's id; nil is the overview.
    let selection: String?
    let select: (String?) -> Void

    @Environment(\.panelStyle) private var style
    @Namespace private var underline

    private enum Density { case full, short, marksOnly }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(.full)
            row(.short)
            row(.marksOnly)
        }
        .frame(width: PanelLayout.contentWidth)
    }

    private func row(_ density: Density) -> some View {
        HStack(spacing: 0) {
            tab(id: nil, title: "전체", tint: .white, mark: nil)
            ForEach(Array(providers.enumerated()), id: \.element.id) { index, usage in
                Spacer(minLength: Self.minimumGap)
                tab(id: usage.id, title: name(of: usage, density), tint: Theme.brand(for: usage.id), mark: mark(index))
            }
        }
    }

    private func name(of usage: ProviderUsage, _ density: Density) -> String {
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
    /// Room around a tab that still counts as it, taken out of the gap between tabs.
    private static let hitPadding: CGFloat = 4

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
                .fixedSize()
                ZStack {
                    Color.clear.frame(height: 2)
                    if isSelected { underlineBar.matchedGeometryEffect(id: "selection", in: underline) }
                }
            }
            .padding(.horizontal, Self.hitPadding)
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

    private var underlineBar: some View {
        Capsule()
            .fill(tint)
            .frame(width: Self.underlineWidth, height: style == .mono ? 1.5 : 2)
    }
}
