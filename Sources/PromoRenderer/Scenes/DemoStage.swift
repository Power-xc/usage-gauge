import SwiftUI
import UsageGaugeCore
import UsageGaugeUI

/// A desktop in motion: the menu bar, the panel following a `DemoScript` and the pointer using it.
/// Laid out in `canvas` points; a scene scales it to the picture it fills.
struct DemoStage: View {
    let script: DemoScript
    let time: Double
    let canvas: CGSize
    var tools = Array(SampleData.tools.prefix(2))
    /// False leaves out the backdrop and the menu bar, for a scene that supplies its own.
    var showsDesktop = true
    var showsPointer = true

    /// The tools as they stand now: filling up from empty at the start of a loop.
    private var shownTools: [ProviderUsage] { script.fill?.apply(to: tools, at: time) ?? tools }

    var body: some View {
        let scale = script.scale.value(at: time)
        ZStack(alignment: .topLeading) {
            if showsDesktop {
                Backdrop()
                MenuBarStrip(providers: shownTools, width: canvas.width)
            }
            panel(scale: scale)
            if let menu = script.menu { StyleMenu(plan: menu, time: time) }
            if showsPointer { pointer }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .environment(\.colorScheme, .dark)
    }

    /// The current face over the one it replaces, crossfading while it does.
    private func panel(scale: Double) -> some View {
        let face = script.face(at: time)
        return ZStack(alignment: .top) {
            if let previous = face.previous, face.mix < 1 { layer(previous, scale: scale) }
            layer(face.current, scale: scale).opacity(face.mix)
        }
        .frame(width: canvas.width, alignment: .top)
        .padding(.top, DemoLayout.panelTop)
    }

    private func layer(_ face: PanelFace, scale: Double) -> some View {
        SamplePanel(tools: shownTools, style: face.style, layout: face.layout, tool: face.tool, hovered: face.hovered,
                    showsPicker: face.showsPicker, showsControls: face.showsControls, scale: scale, frozenAt: time)
    }

    private var pointer: some View {
        let point = script.pointer(at: time, canvas: canvas)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(script.rings(at: time, canvas: canvas).enumerated()), id: \.offset) { _, ring in
                PressRing(age: ring.age).position(ring.point)
            }
            ArrowPointer(press: script.press(at: time)).offset(x: point.x, y: point.y)
        }
    }
}

/// The app's style menu, opened from the menu bar item: a section header and the three styles.
struct StyleMenu: View {
    static let origin = CGPoint(x: 292, y: 30)
    static let width: CGFloat = 188
    static let rowHeight: CGFloat = 22
    static let headerHeight: CGFloat = 22
    static let padding: CGFloat = 6

    let plan: MenuPlan
    let time: Double

    /// Centre of a style's row, where the pointer goes to choose it.
    static func rowCenter(_ index: Int) -> CGPoint {
        CGPoint(x: origin.x + 40, y: origin.y + padding + headerHeight + rowHeight * (CGFloat(index) + 0.5))
    }

    var body: some View {
        let shown = Motion.progress(time, from: plan.opensAt, to: plan.opensAt + 0.12)
            * (1 - Motion.progress(time, from: plan.closesAt, to: plan.closesAt + 0.1))
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            Text("스타일")
                .font(Theme.font(10, .semibold)).foregroundStyle(Theme.faintText)
                .frame(height: Self.headerHeight, alignment: .bottom)
                .padding(.leading, 10)
            ForEach(Array(PanelStyle.allCases.enumerated()), id: \.offset) { index, style in
                row(style, isLit: index == plan.chosen && time >= plan.litAt)
            }
        }
        .padding(Self.padding)
        .frame(width: Self.width, alignment: .leading)
        .background(shape.fill(Color(white: 0.13)))
        .overlay(shape.strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
        .offset(x: Self.origin.x, y: Self.origin.y)
        .opacity(shown)
    }

    private func row(_ style: PanelStyle, isLit: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark").font(.system(size: 9, weight: .semibold))
                .opacity(style == .mono && time < plan.litAt ? 1 : 0)
                .frame(width: 12)
            Text(style.title).font(Theme.font(12.5))
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .frame(height: Self.rowHeight)
        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.accent.opacity(isLit ? 0.3 : 0)))
    }
}
