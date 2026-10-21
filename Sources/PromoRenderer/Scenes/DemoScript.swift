import SwiftUI
import UsageGaugeUI

/// What the panel shows at an instant: the parts a pointer changes by clicking or hovering.
struct PanelFace: Equatable {
    var layout = PanelLayout.dial
    var style = PanelStyle.mono
    var tool: String?
    var hovered: String?
    var showsPicker = false
    var showsControls = false
}

/// Values eased from one key to the next over time.
struct Track {
    let keys: [(at: Double, value: Double)]

    func value(at time: Double) -> Double {
        guard let first = keys.first, let last = keys.last else { return 0 }
        if time <= first.at { return first.value }
        for (from, to) in zip(keys, keys.dropFirst()) where time < to.at {
            return Motion.mix(from.value, to.value, Motion.progress(time, from: from.at, to: to.at))
        }
        return last.value
    }
}

/// Where the pointer goes: a point on the screen, a point on the panel (which moves with the
/// panel's size), or the size bar's knob, which the pointer holds while the size changes.
enum PointerTarget {
    case screen(CGPoint)
    case panel(CGPoint)
    case knob
}

struct PointerStop {
    let at: Double
    let target: PointerTarget
    var isClick = false
}

/// The style menu the pointer opens from the menu bar.
struct MenuPlan {
    let opensAt: Double
    let closesAt: Double
    /// Index in `PanelStyle.allCases` of the item lit while the pointer rests on it, and since when.
    let chosen: Int
    let litAt: Double
}

/// A scripted use of the panel: faces that crossfade at set times, the pointer's stops and the
/// panel's size over time. Times are seconds from the loop's start.
struct DemoScript {
    static let faceFade = 0.2
    static let clickLife = 0.45

    let duration: Double
    let faces: [(at: Double, face: PanelFace)]
    let stops: [PointerStop]
    let scale: Track
    var menu: MenuPlan?
    /// How the tools fill up at the start; nil starts with them full.
    var fill: FillPlan?

    /// The same script with everything after its first moment pushed back by `delay`, so the
    /// panel can fill up before the pointer starts.
    func delayed(by delay: Double, duration: Double, fill: FillPlan) -> DemoScript {
        func later(_ time: Double) -> Double { time > 0 ? time + delay : time }
        var script = DemoScript(
            duration: duration,
            faces: faces.map { (later($0.at), $0.face) },
            stops: stops.map { PointerStop(at: later($0.at), target: $0.target, isClick: $0.isClick) },
            scale: Track(keys: [(0, scale.keys[0].value)] + scale.keys.dropFirst().map { (later($0.at), $0.value) }),
            fill: fill)
        script.menu = menu.map { MenuPlan(opensAt: later($0.opensAt), closesAt: later($0.closesAt), chosen: $0.chosen, litAt: later($0.litAt)) }
        return script
    }

    /// The face at `time` and, while it is still replacing another, that one and how far along it is.
    func face(at time: Double) -> (current: PanelFace, previous: PanelFace?, mix: Double) {
        guard let index = faces.lastIndex(where: { $0.at <= time }) else { return (faces[0].face, nil, 1) }
        guard index > 0 else { return (faces[0].face, nil, 1) }
        let mix = Motion.progress(time, from: faces[index].at, to: faces[index].at + Self.faceFade)
        return (faces[index].face, faces[index - 1].face, mix)
    }

    /// Ages (0...1) of the click rings alive at `time`, with where each was made.
    func rings(at time: Double, canvas: CGSize) -> [(age: Double, point: CGPoint)] {
        stops.filter { $0.isClick && time >= $0.at && time < $0.at + Self.clickLife }.map {
            (age: (time - $0.at) / Self.clickLife, point: position(of: $0, scale: scale.value(at: $0.at), canvas: canvas))
        }
    }

    /// 0...1 while a click is pressing the arrow in.
    func press(at time: Double) -> Double {
        stops.filter { $0.isClick && time >= $0.at }
            .map { 1 - Motion.progress(time, from: $0.at, to: $0.at + 0.16) }.max() ?? 0
    }

    func pointer(at time: Double, canvas: CGSize) -> CGPoint {
        guard let index = stops.lastIndex(where: { $0.at <= time }) else {
            return position(of: stops[0], scale: scale.value(at: time), canvas: canvas)
        }
        guard index + 1 < stops.count else {
            return position(of: stops[index], scale: scale.value(at: time), canvas: canvas)
        }
        let from = stops[index], to = stops[index + 1]
        if case .knob = from.target, case .knob = to.target {
            return position(of: from, scale: scale.value(at: time), canvas: canvas)
        }
        let start = position(of: from, scale: scale.value(at: from.at), canvas: canvas)
        let end = position(of: to, scale: scale.value(at: to.at), canvas: canvas)
        let progress = Motion.progress(time, from: from.at, to: to.at)
        // A slight arc, as a hand moves, instead of a ruler-straight line.
        let dx = end.x - start.x, dy = end.y - start.y
        let bow = sin(.pi * progress) * 0.05
        return CGPoint(x: start.x + dx * progress - dy * bow, y: start.y + dy * progress + dx * bow)
    }

    /// The point on screen a stop means at the given panel size.
    func position(of stop: PointerStop, scale: Double, canvas: CGSize) -> CGPoint {
        switch stop.target {
        case .screen(let point): point
        case .panel(let point): DemoLayout.screen(point, scale: scale, canvas: canvas)
        case .knob: DemoLayout.screen(DemoLayout.knob(scale: scale), scale: scale, canvas: canvas)
        }
    }
}

/// Where the panel's controls sit, measured on the mono panel (in points at 1x), and how the panel
/// is placed on the demo's screen.
enum DemoLayout {
    static let panelWidth: CGFloat = 497
    static let panelTop: CGFloat = 46
    static let gridButton = CGPoint(x: 418, y: 20)
    static let sliderButton = CGPoint(x: 446.5, y: 20)
    /// Tab centres of the two-tool panel: 전체, Claude, Codex.
    static let tabs = [CGPoint(x: 85.5, y: 56), CGPoint(x: 247.5, y: 56), CGPoint(x: 415, y: 56)]
    /// First glyph of the graph picker, the pitch between glyphs and their row.
    static let glyphStart: CGFloat = 31.7
    static let glyphPitch: CGFloat = 39.33
    static let glyphY: CGFloat = 51
    /// The size bar: its knob's travel and row.
    static let barLeft: CGFloat = 63
    static let barTravel: CGFloat = 369
    static let barY: CGFloat = 76
    static let scaleRange = 0.7...1.6

    static func glyph(_ layout: PanelLayout) -> CGPoint {
        let index = PanelLayout.allCases.firstIndex(of: layout) ?? 0
        return CGPoint(x: glyphStart + glyphPitch * CGFloat(index), y: glyphY)
    }

    static func knob(scale: Double) -> CGPoint {
        let fraction = (scale - scaleRange.lowerBound) / (scaleRange.upperBound - scaleRange.lowerBound)
        return CGPoint(x: barLeft + barTravel * fraction, y: barY)
    }

    /// Top-left of the panel, centred under the menu bar.
    static func origin(scale: Double, canvas: CGSize) -> CGPoint {
        CGPoint(x: (canvas.width - panelWidth * scale) / 2, y: panelTop)
    }

    static func screen(_ local: CGPoint, scale: Double, canvas: CGSize) -> CGPoint {
        let origin = origin(scale: scale, canvas: canvas)
        return CGPoint(x: origin.x + local.x * scale, y: origin.y + local.y * scale)
    }
}
