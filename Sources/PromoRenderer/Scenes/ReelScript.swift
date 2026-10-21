import SwiftUI
import UsageGaugeUI

/// The reel's pointer, on the reel's clock: opens the graph picker and clicks through all twelve
/// forms, shows the three styles, opens a tool's page and returns, and drags the size bar.
extension DemoScript {
    /// When each beat starts, in reel seconds.
    enum Reel {
        static let formsStart = 6.5
        static let pickerOpens = 6.8
        static let firstGlyph = 7.2
        static let glyphStep = 0.5
        /// The pointer goes back to the first form, then closes the picker.
        static let returnStep = 0.55
        static let pickerCloses = 13.3
        static let styles: [(style: PanelStyle, start: Double)] = [(.iris, 13.5), (.dot, 14.2), (.mono, 14.9)]
        static let tabOpens = 15.2
        static let tabCloses = 16.2
        static let controlsOpen = 16.6
        static let sizeDrag = 17.0
        static let sizeRange = (small: 0.97, large: 1.07)
        static let duration = 22.0
        /// The panel leaves for the outro.
        static let end = 18.6
    }

    static let reel: DemoScript = {
        func panel(_ point: CGPoint, at time: Double, click: Bool = false) -> PointerStop {
            PointerStop(at: time, target: .panel(point), isClick: click)
        }
        let layouts = PanelLayout.allCases

        var face = PanelFace()
        var faces: [(at: Double, face: PanelFace)] = [(0, face)]
        func show(at time: Double, _ change: (inout PanelFace) -> Void) {
            change(&face)
            faces.append((time, face))
        }
        // One glyph a click; the form changes just after the click lands.
        func glyphTime(_ index: Int) -> Double { Reel.firstGlyph + Reel.glyphStep * Double(index - 1) }

        show(at: Reel.pickerOpens + 0.05) { $0.showsPicker = true }
        var stops = [
            PointerStop(at: 0, target: .screen(CGPoint(x: 420, y: 130))),
            PointerStop(at: Reel.formsStart, target: .screen(CGPoint(x: 420, y: 130))),
            panel(DemoLayout.gridButton, at: Reel.pickerOpens, click: true),
        ]
        for index in 1..<layouts.count {
            show(at: glyphTime(index) + 0.05) { $0.layout = layouts[index] }
            stops.append(panel(DemoLayout.glyph(layouts[index]), at: glyphTime(index), click: true))
        }
        let returnTime = glyphTime(layouts.count - 1) + Reel.returnStep
        show(at: returnTime + 0.05) { $0.layout = .dial }
        stops.append(panel(DemoLayout.glyph(.dial), at: returnTime, click: true))
        show(at: Reel.pickerCloses + 0.05) { $0.showsPicker = false }
        stops.append(panel(DemoLayout.gridButton, at: Reel.pickerCloses, click: true))

        for turn in Reel.styles { show(at: turn.start) { $0.style = turn.style } }
        stops.append(panel(CGPoint(x: 330, y: 150), at: Reel.styles[0].start))

        show(at: Reel.tabOpens + 0.05) { $0.tool = "claude" }
        stops.append(panel(DemoLayout.tabs[1], at: Reel.tabOpens, click: true))
        show(at: Reel.tabCloses + 0.05) { $0.tool = nil }
        stops.append(panel(DemoLayout.tabs[0], at: Reel.tabCloses, click: true))
        show(at: Reel.controlsOpen + 0.05) { $0.showsControls = true }
        stops.append(panel(DemoLayout.sliderButton, at: Reel.controlsOpen, click: true))
        let drag = Reel.sizeDrag
        stops += [
            PointerStop(at: drag, target: .knob),
            PointerStop(at: drag + 0.3, target: .knob),
            PointerStop(at: drag + 1.1, target: .knob),
        ]

        return DemoScript(
            duration: Reel.duration, faces: faces, stops: stops,
            scale: Track(keys: [(0, Reel.sizeRange.small), (drag + 0.3, Reel.sizeRange.small), (drag + 1.1, Reel.sizeRange.large)]))
    }()
}
