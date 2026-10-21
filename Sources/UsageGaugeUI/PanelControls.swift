import SwiftUI

/// Bare glyph that brightens under the pointer; a faint disc (a square in the mono style) marks
/// it while its control is open.
struct HeaderButton: View {
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

/// Bars for the whole panel's opacity and size, under the header while adjusting.
struct PanelControls: View {
    let opacity: Binding<Double>?
    let opacityRange: ClosedRange<Double>
    let scale: Binding<Double>?
    let scaleRange: ClosedRange<Double>

    var body: some View {
        VStack(spacing: 2) {
            if let opacity { ControlRow(title: "투명도", value: opacity, range: opacityRange) }
            if let scale { ControlRow(title: "크기", value: scale, range: scaleRange) }
        }
        .padding(.vertical, 4)
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
