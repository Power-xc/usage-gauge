import SwiftUI

/// One choice per graph form, slid in under the header: a symbol over a short title, the current
/// one underlined in white.
struct LayoutPicker: View {
    let selection: PanelLayout
    let choose: (PanelLayout) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PanelLayout.allCases, id: \.self) { layout in
                LayoutChoice(layout: layout, isSelected: layout == selection) { choose(layout) }
            }
        }
        .frame(width: PanelLayout.contentWidth)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

private struct LayoutChoice: View {
    let layout: PanelLayout
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.panelStyle) private var style

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: layout.symbol).font(.system(size: 12, weight: .medium))
                Text(layout.title)
                    .font(Theme.label(9, .medium, style: style))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Capsule()
                    .fill(.white)
                    .frame(width: 16, height: 1.5)
                    .opacity(isSelected ? 1 : 0)
            }
            .foregroundStyle(isSelected || isHovered ? Theme.primaryText : Theme.faintText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointingHand()
    }
}

extension PanelLayout {
    private static let symbols: [PanelLayout: String] = [
        .dial: "gauge.with.dots.needle.67percent", .bars: "chart.bar.doc.horizontal",
        .columns: "chart.bar.xaxis", .figures: "number",
    ]

    /// Glyph of the form in the picker; a layout without its own gets the picker's symbol.
    var symbol: String { Self.symbols[self] ?? "square.grid.2x2" }
}
