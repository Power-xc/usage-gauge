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
}

private struct PanelPresetKey: EnvironmentKey {
    static let defaultValue = PanelPreset()
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
}

public extension View {
    /// Starts the panel on a tool's detail page and/or with a cell hovered. For still renders.
    func panelPreset(tool: String? = nil, hovered: String? = nil) -> some View {
        environment(\.panelPreset, PanelPreset(tool: tool, hovered: hovered))
    }
}

/// A tool's cell in any layout: brightens under the pointer with a soft glow of the tool's colour,
/// reveals a line with its reset and measuring times without moving anything, and opens the
/// detail page on click. Hover is shown by light only, never by a frame.
struct ToolCell: ViewModifier {
    private static let glowOpacity = 0.16
    private static let glowBlur: CGFloat = 22
    private static let boost = 0.08
    private static let revealHeight: CGFloat = 12

    let usage: ProviderUsage

    @State private var isPointerOver = false
    @Environment(\.panelStyle) private var style
    @Environment(\.toolInteraction) private var interaction
    @Environment(\.panelPreset) private var preset

    func body(content: Content) -> some View {
        let isHovered = isPointerOver || preset.hovered == usage.id
        let tint = Theme.brand(for: usage.id)
        content
            .brightness(isHovered ? Self.boost : 0)
            .background {
                Ellipse()
                    .fill(tint.opacity(Self.glowOpacity))
                    .blur(radius: Self.glowBlur)
                    .padding(.horizontal, 24)
                    .opacity(isHovered ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                Text(HoverDetail.line(for: usage))
                    .font(Theme.figure(9, .regular, style: style))
                    .foregroundStyle(Theme.mutedText)
                    .fixedSize()
                    .offset(y: style == .mono ? -3 : Self.revealHeight)
                    .opacity(isHovered ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onHover { isPointerOver = $0 }
            .animation(.easeOut(duration: 0.16), value: isHovered)
            .modifier(OpensTool(id: usage.id, open: interaction.open))
    }
}

/// Clickable only when there is somewhere to go; then the pointer turns into a hand.
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

extension View {
    /// The pointing-hand cursor while the pointer is over the view.
    func pointingHand() -> some View { modifier(PointingHand()) }
}

private struct PointingHand: ViewModifier {
    @State private var isPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                guard inside != isPushed else { return }
                isPushed = inside
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .onDisappear {
                guard isPushed else { return }
                isPushed = false
                NSCursor.pop()
            }
    }
}
