import SwiftUI
import UsageGaugeCore

/// Providers in rows of equal cells. The mono style sets every cell in a hairline grid that runs
/// edge to edge; the others space them out. Cells get the width left for their content.
struct ProviderGrid<Cell: View>: View {
    let providers: [ProviderUsage]
    let columns: Int
    let cell: (_ index: Int, _ usage: ProviderUsage, _ width: CGFloat) -> Cell

    @Environment(\.panelStyle) private var style

    var body: some View {
        VStack(spacing: style == .mono ? 0 : PanelLayout.blockSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                if style == .mono { GridRule(isVertical: false) }
                HStack(alignment: .top, spacing: style == .mono ? 0 : PanelLayout.cellSpacing) {
                    ForEach(row, id: \.usage.id) { entry in
                        if style == .mono && entry.index % columns > 0 { GridRule(isVertical: true) }
                        cell(entry.index, entry.usage, cellWidth)
                            .frame(width: cellWidth)
                            .padding(.horizontal, style == .mono ? Theme.panelPadding : 0)
                            .padding(.vertical, style == .mono ? Theme.panelPadding : 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Mono cells are one point wider each to pay for the rules between them, as in the dial grid.
    private var cellWidth: CGFloat {
        let count = CGFloat(columns)
        if style == .mono {
            // The grid runs edge to edge, so its cells also cover the panel padding, plus one rule.
            let total = PanelLayout.contentWidth + 2 * Theme.panelPadding + 1
            return ((total - (count - 1)) / count - 2 * Theme.panelPadding).rounded(.down)
        }
        return ((PanelLayout.contentWidth - (count - 1) * PanelLayout.cellSpacing) / count).rounded(.down)
    }

    private var rows: [[(index: Int, usage: ProviderUsage)]] {
        let entries = providers.enumerated().map { (index: $0.offset, usage: $0.element) }
        return stride(from: 0, to: entries.count, by: columns).map {
            Array(entries[$0..<min($0 + columns, entries.count)])
        }
    }
}

/// One-point line of the mono style's grid.
struct GridRule: View {
    let isVertical: Bool

    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: isVertical ? 1 : nil, height: isVertical ? nil : 1)
    }
}
