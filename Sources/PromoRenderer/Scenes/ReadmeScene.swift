import SwiftUI
import UsageGaugeUI

/// README hero loop: the panel fills up from empty, then is used. The pointer opens the graph picker and tries a few
/// forms, opens a tool's page and returns, resizes the panel with the size bar, and picks another
/// style from the menu bar, then everything settles back and drains to empty, where the loop starts again.
struct ReadmeScene: View {
    static let size = CGSize(width: 960, height: 540)
    /// The desktop is laid out at 1x and zoomed to fill the picture, so the panel reads at README width.
    static let zoom: CGFloat = 1.35
    static let canvas = CGSize(width: size.width / zoom, height: size.height / zoom)
    static let script = DemoScript.hero
    static let duration = script.duration
    /// 12.5 fps is exactly 8 centiseconds a frame, the GIF's native step; no frame is dropped or doubled.
    static let fps = 12.5

    let time: Double

    var body: some View {
        DemoStage(script: Self.script, time: time, canvas: Self.canvas)
            .scaleEffect(Self.zoom, anchor: .topLeading)
            .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }
}

extension DemoScript {
    private static let rest = CGPoint(x: 560, y: 330)
    private static let menuItem = CGPoint(x: 372, y: 15)

    static let hero: DemoScript = {
        func panel(_ point: CGPoint, at time: Double, click: Bool = false) -> PointerStop {
            PointerStop(at: time, target: .panel(point), isClick: click)
        }
        func glyph(_ layout: PanelLayout, at time: Double) -> PointerStop {
            panel(DemoLayout.glyph(layout), at: time, click: true)
        }
        let irisRow = StyleMenu.rowCenter(PanelStyle.allCases.firstIndex(of: .iris) ?? 1)

        var face = PanelFace()
        var faces: [(at: Double, face: PanelFace)] = []
        func show(at time: Double, _ change: (inout PanelFace) -> Void) {
            change(&face)
            faces.append((time, face))
        }
        faces.append((0, face))
        show(at: 1.45) { $0.showsPicker = true }
        show(at: 2.25) { $0.layout = .trend }
        show(at: 3.35) { $0.layout = .orbit }
        show(at: 4.45) { $0.layout = .spark }
        show(at: 5.55) { $0.layout = .dial }
        show(at: 6.55) { $0.showsPicker = false }
        show(at: 7.45) { $0.tool = "claude" }
        show(at: 9.05) { $0.tool = nil }
        show(at: 9.75) { $0.hovered = "codex" }
        show(at: 10.35) { $0.hovered = nil }
        show(at: 10.8) { $0.showsControls = true }
        show(at: 14.65) { $0.showsControls = false }
        show(at: 16.75) { $0.style = .iris }
        show(at: 17.9) { $0.style = .mono }

        let stops = [
            PointerStop(at: 0, target: .screen(rest)),
            PointerStop(at: 0.5, target: .screen(rest)),
            panel(DemoLayout.gridButton, at: 1.4, click: true),
            glyph(.trend, at: 2.2),
            glyph(.orbit, at: 3.3),
            glyph(.spark, at: 4.4),
            glyph(.dial, at: 5.5),
            panel(DemoLayout.gridButton, at: 6.5, click: true),
            panel(DemoLayout.tabs[1], at: 7.4, click: true),
            panel(DemoLayout.tabs[0], at: 9.0, click: true),
            panel(CGPoint(x: 360, y: 125), at: 9.7),
            panel(CGPoint(x: 360, y: 125), at: 10.2),
            panel(DemoLayout.sliderButton, at: 10.75, click: true),
            PointerStop(at: 11.4, target: .knob),
            PointerStop(at: 11.7, target: .knob),
            PointerStop(at: 12.5, target: .knob),
            PointerStop(at: 13.0, target: .knob),
            PointerStop(at: 13.8, target: .knob),
            panel(DemoLayout.sliderButton, at: 14.6, click: true),
            PointerStop(at: 15.45, target: .screen(menuItem), isClick: true),
            PointerStop(at: 16.15, target: .screen(irisRow)),
            PointerStop(at: 16.7, target: .screen(irisRow), isClick: true),
            PointerStop(at: 18.3, target: .screen(rest)),
        ]
        let used = DemoScript(
            duration: 18.4,
            faces: faces,
            stops: stops,
            scale: Track(keys: [(0, 1), (11.7, 1), (12.5, 1.25), (13.0, 1.25), (13.8, 1)]),
            menu: MenuPlan(opensAt: 15.5, closesAt: 16.75, chosen: 1, litAt: 16.2))
        // Everything fills up from empty first and drains again at the end, so the loop restarts clean.
        let lead = 1.0, drain = 0.5
        return used.delayed(by: lead, duration: used.duration + lead + drain + 0.1,
                            fill: FillPlan(start: 0.1, duration: 1.3, stagger: 0.25,
                                           resetAt: used.duration + lead, resetDuration: drain))
    }()
}
