import Foundation

enum Preferences {
    static let opacityRange: ClosedRange<Double> = 0.3...1.0

    private static let defaults = UserDefaults.standard
    private static let panelVisibleKey = "panelVisible"
    private static let panelOpacityKey = "panelOpacity"
    private static let adaptiveTintKey = "adaptiveTint"

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
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
