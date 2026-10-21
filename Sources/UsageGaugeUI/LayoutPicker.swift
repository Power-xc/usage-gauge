import SwiftUI

/// One glyph per graph form, slid in under the header: the current one underlined in white, and the
/// title of the form under the pointer (or the current one) in a line below.
struct LayoutPicker: View {
    let selection: PanelLayout
    let choose: (PanelLayout) -> Void

    @State private var hovered: PanelLayout?
    @Environment(\.panelStyle) private var style

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(PanelLayout.allCases, id: \.self) { layout in
                    LayoutChoice(layout: layout, isSelected: layout == selection, hovered: $hovered) { choose(layout) }
                }
            }
            Text((hovered ?? selection).title)
                .font(Theme.label(TypeScale.caption, .medium, style: style))
                .foregroundStyle(Theme.mutedText)
        }
        .frame(width: PanelLayout.contentWidth)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

private struct LayoutChoice: View {
    let layout: PanelLayout
    let isSelected: Bool
    @Binding var hovered: PanelLayout?
    let action: () -> Void

    var body: some View {
        let isHovered = hovered == layout
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: layout.symbol).font(.system(size: 13, weight: .medium)).frame(height: 16)
                Capsule()
                    .fill(.white)
                    .frame(width: 14, height: 1.5)
                    .opacity(isSelected ? 1 : 0)
            }
            .foregroundStyle(isSelected || isHovered ? Theme.primaryText : Theme.faintText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside { hovered = layout } else if hovered == layout { hovered = nil }
        }
        .pointingHand()
        .help(layout.title)
    }
}
