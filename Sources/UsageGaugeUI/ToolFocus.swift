import SwiftUI
import UsageGaugeCore

/// Which tool the pointer is on in a chart that draws every tool at once (the orbit's rings, the
/// constellation's nodes). The marks of that tool brighten and the others dim.
struct ToolFocus {
    var tool: String?
    var update: (_ id: String, _ isInside: Bool) -> Void = { _, _ in }

    /// A chart's marks other than the focused tool's are drawn at this share of their strength.
    static let dimmedOpacity = 0.5
    static let motion = Animation.easeOut(duration: 0.16)

    func isDimmed(_ id: String) -> Bool { tool != nil && tool != id }
}

private struct ToolFocusKey: EnvironmentKey {
    static let defaultValue = ToolFocus()
}

extension EnvironmentValues {
    var toolFocus: ToolFocus {
        get { self[ToolFocusKey.self] }
        set { self[ToolFocusKey.self] = newValue }
    }
}

/// Holds the hover of a one-chart layout and hands it to the marks inside (see `toolMark`).
private struct ToolFocusScope: ViewModifier {
    @State private var pointerTool: String?
    @Environment(\.panelPreset) private var preset

    func body(content: Content) -> some View {
        content.environment(\.toolFocus, ToolFocus(tool: pointerTool ?? preset.hovered) { id, isInside in
            if isInside { pointerTool = id } else if pointerTool == id { pointerTool = nil }
        })
    }
}

/// One tool's mark in a chart: focuses its tool under the pointer, dims when another is focused
/// and opens the tool's page on click.
private struct ToolMark: ViewModifier {
    let id: String

    @Environment(\.toolFocus) private var focus
    @Environment(\.toolInteraction) private var interaction

    func body(content: Content) -> some View {
        content
            .opacity(focus.isDimmed(id) ? ToolFocus.dimmedOpacity : 1)
            .contentShape(Rectangle())
            .onHover { focus.update(id, $0) }
            .animation(ToolFocus.motion, value: focus.tool)
            .opensTool(id, via: interaction.open)
    }
}

extension View {
    /// Makes this view's content the hover and click target of a chart whose layout called
    /// `toolFocusScope()` above it.
    func toolMark(_ id: String) -> some View { modifier(ToolMark(id: id)) }

    /// Shares the focused tool with the `toolMark`s inside.
    func toolFocusScope() -> some View { modifier(ToolFocusScope()) }
}
