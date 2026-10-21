import SwiftUI
import UsageGaugeUI

/// The two-tool panel the reel's pointer uses, on the reel's clock: the burn-rate projection, all
/// twelve graphs from the header and the three styles; then the panel keeps turning through the
/// styles while the pointer opens a tool's page, hovers a cell and drags the size and opacity bars;
/// last the app menu, and the panel hidden to leave the menu bar.
extension ReelScript {
    private static let graphStep = 0.36
    private static let firstGlyph = 8.95
    private static let styleTurns: [(style: PanelStyle, at: Double)] = [(.iris, 14.7), (.dot, 15.75)]
    /// Where the pointer waits while it is not using the panel.
    private static let aside = CGPoint(x: 600, y: 330)
    /// The looks the hovered panel turns through, each with a spot on its Codex cell that leaves
    /// the cell's text readable in the close-up.
    private static let hoverLooks: [(at: Double, layout: PanelLayout, style: PanelStyle, point: CGPoint)] = [
        (20.35, .dial, .iris, CGPoint(x: 298, y: 128)),
        (21.0, .capsule, .dot, CGPoint(x: 330, y: 150)),
        (21.65, .burst, .mono, CGPoint(x: 290, y: 175)),
        (22.3, .dial, .dot, CGPoint(x: 298, y: 126)),
    ]

    /// When the n-th graph of the picker appears.
    static func graphTime(_ index: Int) -> Double { firstGlyph + graphStep * Double(index) + 0.05 }

    static let demo: DemoScript = {
        let writer = ScriptWriter(PanelFace(layout: .trend))
        writer.move(.screen(aside), at: 0)
        writer.move(.screen(aside), at: 8.2)
        graphs(writer)
        writer.move(.screen(aside), at: 14.6)
        for turn in styleTurns { writer.show(at: turn.at) { $0.style = turn.style } }
        page(writer)
        hover(writer)
        adjust(writer)
        menu(writer)

        var script = DemoScript(duration: duration, faces: writer.faces, stops: writer.stops,
                                scale: Track(keys: [(0, 1), (23.7, 1), (24.3, 1.2)]))
        script.opacity = Track(keys: [(0, 1), (24.75, 1), (25.15, 0.5), (25.5, 1)])
        script.presence = Track(keys: [(0, 1), (29.15, 1), (29.45, 0)])
        script.pointerPresence = Track(keys: [(0, 0), (8.25, 0), (8.45, 1)])
        script.appMenu = (menuPlan, menuOrigin)
        // The twelve forms cut almost straight from one to the next; styles and pages still blend.
        let cycling = graphTime(0)...graphTime(12)
        script.fade = { cycling.contains($0) ? 0.07 : 0.28 }
        return script
    }()

    /// Opens the picker and clicks every form in order, then goes back to the dial and closes it.
    private static func graphs(_ writer: ScriptWriter) {
        writer.click(DemoLayout.gridButton, at: 8.6) { $0.showsPicker = true }
        for (index, layout) in PanelLayout.allCases.enumerated() {
            writer.click(DemoLayout.glyph(layout), at: firstGlyph + graphStep * Double(index)) { $0.layout = layout }
        }
        writer.click(DemoLayout.glyph(.dial), at: firstGlyph + graphStep * 12 + 0.05) { $0.layout = .dial }
        writer.click(DemoLayout.gridButton, at: 13.5) { $0.showsPicker = false }
    }

    /// Opens Claude's page from its tab, lets the page turn through the styles, and goes back.
    private static func page(_ writer: ScriptWriter) {
        let claude = DemoLayout.tab(1, .dot)
        writer.move(.screen(aside), at: 16.75)
        writer.click(claude, at: 17.3) { $0.tool = "claude" }
        writer.show(at: 18.1) { $0.style = .mono }
        writer.show(at: 18.85) { $0.style = .iris }
        writer.move(.panel(claude), at: 19.05)
        writer.click(DemoLayout.tab(0, .iris), at: 19.5) { $0.tool = nil }
    }

    /// Hovers the Codex cell, which keeps its tint and reset time while the panel turns through
    /// graphs and styles under the pointer.
    private static func hover(_ writer: ScriptWriter) {
        let first = hoverLooks[0], last = hoverLooks[hoverLooks.count - 1]
        writer.move(.panel(first.point), at: first.at - 0.05)
        writer.show(at: first.at) { $0.hovered = "codex" }
        for (previous, look) in zip(hoverLooks, hoverLooks.dropFirst()) {
            writer.move(.panel(previous.point), at: look.at)
            writer.show(at: look.at) {
                $0.layout = look.layout
                $0.style = look.style
            }
            writer.move(.panel(look.point), at: look.at + 0.25)
        }
        writer.move(.panel(last.point), at: 22.8)
        writer.show(at: 22.85) { $0.hovered = nil }
    }

    /// Opens the bars and drags the size up, then, in the next style, the opacity down and back.
    private static func adjust(_ writer: ScriptWriter) {
        writer.click(DemoLayout.sliderButton(.dot), at: 23.15) { $0.showsControls = true }
        for time in [23.5, 23.7, 24.3] { writer.move(.knob, at: time) }
        writer.show(at: 24.45) { $0.style = .mono }
        for time in [24.6, 24.75, 25.5] { writer.move(.opacityKnob, at: time) }
        writer.click(DemoLayout.sliderButton(.mono), at: 25.8) { $0.showsControls = false }
    }

    /// Right-clicks the menu bar item, opens 그래프 and picks 별자리; later a left click on the item
    /// hides the panel.
    private static func menu(_ writer: ScriptWriter) {
        let graphRow = AppMenu.rowCenter(.graph), star = AppMenu.submenuCenter(.constellation)
        func onMenu(_ point: CGPoint) -> PointerTarget {
            .screen(CGPoint(x: menuOrigin.x + point.x, y: menuOrigin.y + point.y))
        }
        writer.move(.screen(menuItem), at: 26.45, click: true)
        writer.move(onMenu(graphRow), at: 26.9)
        writer.move(onMenu(CGPoint(x: graphRow.x + 150, y: graphRow.y)), at: 27.1)
        writer.move(onMenu(star), at: 27.45)
        writer.move(onMenu(star), at: 27.65, click: true)
        writer.show(at: 27.75) { $0.layout = .constellation }
        writer.move(.screen(menuItem), at: 28.95)
        writer.move(.screen(menuItem), at: 29.1, click: true)
    }

    private static let menuPlan = AppMenuPlan(
        opensAt: 26.5, closesAt: 27.7,
        lit: [(26.5, nil), (26.85, .graph)],
        submenuAt: 26.95, current: .dial,
        submenuLit: [(26.95, nil), (27.4, .constellation)])
}

/// Collects a script's faces and pointer stops as it is written, in time order.
final class ScriptWriter {
    private(set) var faces: [(at: Double, face: PanelFace)]
    private(set) var stops: [PointerStop] = []
    private var face: PanelFace

    init(_ face: PanelFace) {
        self.face = face
        faces = [(0, face)]
    }

    func show(at time: Double, _ change: (inout PanelFace) -> Void) {
        change(&face)
        faces.append((time, face))
    }

    func move(_ target: PointerTarget, at time: Double, click: Bool = false) {
        stops.append(PointerStop(at: time, target: target, isClick: click))
    }

    /// A click on the panel, and what it changes just after it lands.
    func click(_ point: CGPoint, at time: Double, _ change: (inout PanelFace) -> Void) {
        move(.panel(point), at: time, click: true)
        show(at: time + 0.05, change)
    }
}
