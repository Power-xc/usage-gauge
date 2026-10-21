import AppKit
import SwiftUI
import UsageGaugeCore

/// What the panel's cells can do: which one the pointer is over and a way to open a tool's
/// detail page. Layouts do not know about it; `ProviderGrid` wraps every cell in `ToolCell`.
struct ToolInteraction {
    /// Opens a tool's detail page; nil when there is nothing to open (a single tool).
    var open: ((String) -> Void)?
}

private struct ToolInteractionKey: EnvironmentKey {
    static let defaultValue = ToolInteraction()
}

/// Selection and hover a still render starts from, so the stills can show a state no pointer is in.
struct PanelPreset: Equatable {
    var tool: String?
    var hovered: String?
    var showsPicker = false
    var showsControls = false
}

private struct PanelPresetKey: EnvironmentKey {
    static let defaultValue = PanelPreset()
}

/// What a cell tells its content: whether the pointer is over it, and how wide it is, so a caption
/// can give way to the hover line in the room it already has (see `RevealingCaption`).
struct CellState {
    var isHovered = false
    var width: CGFloat = .infinity
}

private struct CellStateKey: EnvironmentKey {
    static let defaultValue = CellState()
}

extension EnvironmentValues {
    var toolInteraction: ToolInteraction {
        get { self[ToolInteractionKey.self] }
        set { self[ToolInteractionKey.self] = newValue }
    }

    var panelPreset: PanelPreset {
        get { self[PanelPresetKey.self] }
        set { self[PanelPresetKey.self] = newValue }
    }

    var cellState: CellState {
        get { self[CellStateKey.self] }
        set { self[CellStateKey.self] = newValue }
    }
}

public extension View {
    /// Starts the panel on a tool's detail page, with a cell hovered, or with the graph picker or
    /// the opacity and size bars open. For still renders.
    func panelPreset(tool: String? = nil, hovered: String? = nil, picker: Bool = false,
                     controls: Bool = false) -> some View {
        environment(\.panelPreset, PanelPreset(tool: tool, hovered: hovered, showsPicker: picker, showsControls: controls))
    }
}

/// A tool's cell in any grid layout: brightens under the pointer with a flat tint of the tool's
/// colour, tells its content so (a caption then gives way to the reset and measuring times, see
/// `RevealingCaption`) and opens the detail page on click. Hover is shown by light and colour only, never by a frame.
struct ToolCell: ViewModifier {
    private static let tintOpacity = 0.08
    private static let tintBleed: CGFloat = 8
    private static let tintRadius: CGFloat = 12
    private static let boost = 0.08

    let usage: ProviderUsage
    let width: CGFloat
    /// Space kept around the content (the mono grid's cell padding); the tint and the hit area cover it.
    let padding: CGFloat

    @State private var isPointerOver = false
    @Environment(\.panelStyle) private var style
    @Environment(\.toolInteraction) private var interaction
    @Environment(\.panelPreset) private var preset

    func body(content: Content) -> some View {
        let isHovered = isPointerOver || preset.hovered == usage.id
        content
            .environment(\.cellState, CellState(isHovered: isHovered, width: width))
            .brightness(isHovered ? Self.boost : 0)
            .padding(padding)
            .background { tint.opacity(isHovered ? 1 : 0).allowsHitTesting(false) }
            .contentShape(Rectangle())
            .onHover { isPointerOver = $0 }
            .animation(.easeOut(duration: 0.16), value: isHovered)
            .opensTool(usage.id, via: interaction.open)
    }

    private var tint: some View {
        let bleed = style == .mono ? 0 : -Self.tintBleed
        return RoundedRectangle(cornerRadius: style == .mono ? 0 : Self.tintRadius, style: .continuous)
            .fill(Theme.brand(for: usage.id).opacity(Self.tintOpacity))
            .padding(bleed)
    }
}

/// A caption that gives way to the tool's reset and measuring times while its cell is hovered,
/// in the same place, so the line never lands on a bar, a rule or the next row.
struct RevealingCaption<Caption: View>: View {
    let usage: ProviderUsage
    var alignment: Alignment = .leading
    /// Always the short wording, for a caption slot narrower than the cell.
    var isCompact = false
    @ViewBuilder let caption: Caption

    @Environment(\.cellState) private var cell
    @Environment(\.panelStyle) private var style

    var body: some View {
        let isShown = cell.isHovered && usage.isAvailable
        caption
            .opacity(isShown ? 0 : 1)
            .overlay(alignment: alignment) {
                Text(HoverDetail.line(for: usage, isCompact: isCompact || cell.width < HoverDetail.fullLineWidth))
                    .font(Theme.figure(TypeScale.caption, .regular, style: style))
                    .foregroundStyle(Theme.mutedText)
                    .fixedSize()
                    .opacity(isShown ? 1 : 0)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    /// Clickable only when there is somewhere to go; then the pointer turns into a hand.
    func opensTool(_ id: String, via open: ((String) -> Void)?) -> some View {
        modifier(OpensTool(id: id, open: open))
    }

    /// The pointing-hand cursor while the pointer is over the view (and `isEnabled`).
    func pointingHand(isEnabled: Bool = true) -> some View { modifier(PointingHand(isEnabled: isEnabled)) }
}

private struct OpensTool: ViewModifier {
    let id: String
    let open: ((String) -> Void)?

    func body(content: Content) -> some View {
        if let open {
            content.onTapGesture { open(id) }.pointingHand()
        } else {
            content
        }
    }
}

private struct PointingHand: ViewModifier {
    let isEnabled: Bool

    @State private var isInside = false
    @State private var isPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { isInside = $0; sync() }
            .onChange(of: isEnabled) { sync() }
            .onDisappear {
                isInside = false
                sync()
            }
    }

    /// Pushes or pops the cursor so pushes and pops stay paired.
    private func sync() {
        let shouldPush = isInside && isEnabled
        guard shouldPush != isPushed else { return }
        isPushed = shouldPush
        if shouldPush { NSCursor.pointingHand.push() } else { NSCursor.pop() }
    }
}
