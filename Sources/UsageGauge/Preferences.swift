import Foundation
import UsageGaugeUI

enum Preferences {
    static let opacityRange: ClosedRange<Double> = 0.3...1.0
    static let scaleRange: ClosedRange<Double> = 0.7...1.6

    private static let defaults = UserDefaults.standard
    private static let panelVisibleKey = "panelVisible"
    private static let panelOpacityKey = "panelOpacity"
    private static let panelScaleKey = "panelScale"
    private static let adaptiveTintKey = "adaptiveTint"
    private static let panelStyleKey = "panelStyle"
    private static let panelLayoutKey = "panelLayout"
    private static let menuBarBarsKey = "menuBarBars"

    /// Whether the menu bar item draws the small bars between each name and its figure.
    static var showsMenuBarBars: Bool {
        get { defaults.object(forKey: menuBarBarsKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: menuBarBarsKey) }
    }
    private static let panelLeftKey = "panelLeft"
    private static let panelTopKey = "panelTop"

    /// Top-left corner of the panel in global screen coordinates; nil until it has been placed.
    static var panelTopLeft: CGPoint? {
        get {
            guard let left = defaults.object(forKey: panelLeftKey) as? Double,
                  let top = defaults.object(forKey: panelTopKey) as? Double else { return nil }
            return CGPoint(x: left, y: top)
        }
        set {
            defaults.set(newValue.map { Double($0.x) }, forKey: panelLeftKey)
            defaults.set(newValue.map { Double($0.y) }, forKey: panelTopKey)
        }
    }

    static var panelStyle: PanelStyle {
        get { defaults.string(forKey: panelStyleKey).flatMap(PanelStyle.init(rawValue:)) ?? .mono }
        set { defaults.set(newValue.rawValue, forKey: panelStyleKey) }
    }

    static var panelLayout: PanelLayout {
        get { defaults.string(forKey: panelLayoutKey).flatMap(PanelLayout.init(rawValue:)) ?? .dial }
        set { defaults.set(newValue.rawValue, forKey: panelLayoutKey) }
    }

    static var isPanelVisible: Bool {
        get { defaults.object(forKey: panelVisibleKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: panelVisibleKey) }
    }

    /// Whether the glass deepens or clears to suit what is behind it.
    static var isAdaptiveTint: Bool {
        get { defaults.object(forKey: adaptiveTintKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: adaptiveTintKey) }
    }

    static var panelOpacity: Double {
        get { (defaults.object(forKey: panelOpacityKey) as? Double ?? 1.0).clamped(to: opacityRange) }
        set { defaults.set(newValue.clamped(to: opacityRange), forKey: panelOpacityKey) }
    }

    static var panelScale: Double {
        get { (defaults.object(forKey: panelScaleKey) as? Double ?? 1.0).clamped(to: scaleRange) }
        set { defaults.set(newValue.clamped(to: scaleRange), forKey: panelScaleKey) }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
