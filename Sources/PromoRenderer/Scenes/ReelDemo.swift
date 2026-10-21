import SwiftUI
import UsageGaugeUI

/// The two-tool panel the reel's pointer uses, on the reel's clock: the burn-rate projection, all
/// twelve graphs from the header, the three styles, a tool's page and a hover, the size and
/// opacity bars, the app menu, and the panel hidden to leave the menu bar.
extension ReelScript {
    private static let graphStep = 0.36
    private static let firstGlyph = 8.95
    private static let styleTurns: [(style: PanelStyle, at: Double)] = [(.iris, 13.85), (.dot, 14.6), (.mono, 15.35)]
    /// On the Codex dial, so the pointer leaves the cell's text readable in the close-up.
    private static let codexCell = CGPoint(x: 300, y: 138)

    /// When the n-th graph of the picker appears.
    static func graphTime(_ index: Int) -> Double { firstGlyph + graphStep * Double(index) + 0.05 }

    static let demo: DemoScript = {
        let writer = ScriptWriter(PanelFace(layout: .trend))
        writer.move(.screen(CGPoint(x: 600, y: 330)), at: 0)
        writer.move(.screen(CGPoint(x: 600, y: 330)), at: 8.2)
        graphs(writer)
        for turn in styleTurns { writer.show(at: turn.at) { $0.style = turn.style } }
        touches(writer)
        adjust(writer)
        menu(writer)

        var script = DemoScript(duration: duration, faces: writer.faces, stops: writer.stops,
                                scale: Track(keys: [(0, 1), (19.35, 1), (19.95, 1.2)]))
        script.opacity = Track(keys: [(0, 1), (20.35, 1), (20.75, 0.5), (21.1, 1)])
        script.presence = Track(keys: [(0, 1), (24.65, 1), (24.95, 0)])
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

    /// A tool's page and back, then a hover that turns the Codex caption into its reset time.
    private static func touches(_ writer: ScriptWriter) {
        writer.move(.screen(CGPoint(x: 560, y: 330)), at: 15.6)
        writer.click(DemoLayout.tabs[1], at: 16.2) { $0.tool = "claude" }
        writer.click(DemoLayout.tabs[0], at: 17.1) { $0.tool = nil }
        writer.move(.panel(codexCell), at: 17.5)
        writer.show(at: 17.55) { $0.hovered = "codex" }
        writer.move(.panel(codexCell), at: 18.45)
        writer.show(at: 18.5) { $0.hovered = nil }
    }

    /// Opens the bars and drags the size up, then the opacity down and back.
    private static func adjust(_ writer: ScriptWriter) {
        writer.click(DemoLayout.sliderButton, at: 18.75) { $0.showsControls = true }
        for time in [19.15, 19.35, 19.95] { writer.move(.knob, at: time) }
        for time in [20.2, 20.35, 21.1] { writer.move(.opacityKnob, at: time) }
        writer.click(DemoLayout.sliderButton, at: 21.4) { $0.showsControls = false }
    }

    /// Right-clicks the menu bar item, opens 그래프 and picks 별자리; later a left click on the item
    /// hides the panel.
    private static func menu(_ writer: ScriptWriter) {
        let graphRow = AppMenu.rowCenter(.graph), star = AppMenu.submenuCenter(.constellation)
        func onMenu(_ point: CGPoint) -> PointerTarget {
            .screen(CGPoint(x: menuOrigin.x + point.x, y: menuOrigin.y + point.y))
        }
        writer.move(.screen(menuItem), at: 21.95, click: true)
        writer.move(onMenu(graphRow), at: 22.4)
        writer.move(onMenu(CGPoint(x: graphRow.x + 150, y: graphRow.y)), at: 22.6)
        writer.move(onMenu(star), at: 22.95)
        writer.move(onMenu(star), at: 23.15, click: true)
        writer.show(at: 23.25) { $0.layout = .constellation }
        writer.move(.screen(menuItem), at: 24.45)
        writer.move(.screen(menuItem), at: 24.6, click: true)
    }

    private static let menuPlan = AppMenuPlan(
        opensAt: 22.0, closesAt: 23.2,
        lit: [(22.0, nil), (22.35, .graph)],
        submenuAt: 22.45, current: .dial,
        submenuLit: [(22.45, nil), (22.9, .constellation)])
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
