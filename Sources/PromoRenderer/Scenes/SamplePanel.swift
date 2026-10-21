import SwiftUI
import UsageGaugeCore
import UsageGaugeUI

/// The panel exactly as the app builds it (every header control present), over the sample moment.
/// The `scale` is both what the size bar shows and how large the panel is drawn.
struct SamplePanel: View {
    var tools = SampleData.tools
    var style = PanelStyle.mono
    var layout = PanelLayout.dial
    var tool: String?
    var hovered: String?
    var showsPicker = false
    var showsControls = false
    var scale = 1.0
    var frozenAt: TimeInterval = 3

    var body: some View {
        GaugeView(providers: tools, status: SampleData.status, now: SampleData.now, onClose: {},
                  opacity: .constant(1), scale: .constant(scale), style: style, layout: layout,
                  history: SampleData.history, frozenAt: frozenAt, onLayout: { _ in })
            .panelPreset(tool: tool, hovered: hovered, picker: showsPicker, controls: showsControls)
            .modifier(RenderedSurface(style: style))
            .panelScale(scale)
    }
}

/// A scene's content on the flat backdrop with room around it, in the dark colour scheme.
struct Staged<Content: View>: View {
    var margin: CGFloat = 64
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(margin)
            .background(Backdrop())
            .environment(\.colorScheme, .dark)
    }
}

/// A small caption under a piece of the scene.
struct Caption: View {
    let title: String
    var size: CGFloat = 20
    var detail: String?

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(Theme.font(size, .semibold)).foregroundStyle(Theme.mutedText)
            if let detail {
                Text(detail).font(Theme.mono(size * 0.62, .medium)).foregroundStyle(Theme.faintText)
            }
        }
    }
}
