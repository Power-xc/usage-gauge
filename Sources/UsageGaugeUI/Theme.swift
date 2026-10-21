import SwiftUI
import UsageGaugeCore

/// Visual tokens: smoked-glass ink, white type at three opacities, one lavender accent and each
/// tool's signature colour.
public enum Theme {
    /// Deep, slightly cool ink for the glass smoke; plain black reads as muddy grey over light content.
    public static let smoke = Color(red: 0.035, green: 0.04, blue: 0.058)
    public static let accent = Color(red: 201 / 255, green: 182 / 255, blue: 255 / 255)
    public static let warning = Color(red: 255 / 255, green: 206 / 255, blue: 122 / 255)
    public static let critical = Color(red: 255 / 255, green: 128 / 255, blue: 128 / 255)

    public static let primaryText = Color.white
    public static let mutedText = Color.white.opacity(0.62)
    public static let faintText = Color.white.opacity(0.42)
    public static let hairline = Color.white.opacity(0.10)
    public static let track = Color.white.opacity(0.10)

    public static let panelCornerRadius: CGFloat = 18
    public static let panelPadding: CGFloat = 12
    public static let columnWidth: CGFloat = 108

    public static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Large display figures: tight, fixed-width digits that read as type, not as a readout.
    public static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold).monospacedDigit()
    }

    /// Rounded, fixed-width digits, as in Apple's activity and battery readouts.
    public static func number(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    /// Signature colour of each tool; unknown providers fall back to the accent.
    public static func brand(for providerID: String) -> Color {
        switch providerID {
        case "claude": Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255)
        case "codex", "openai": Color(red: 16 / 255, green: 163 / 255, blue: 127 / 255)
        case "gemini", "antigravity": Color(red: 78 / 255, green: 134 / 255, blue: 248 / 255)
        case "copilot": Color(red: 140 / 255, green: 108 / 255, blue: 245 / 255)
        case "cursor": Color(red: 214 / 255, green: 218 / 255, blue: 228 / 255)
        default: accent
        }
    }

    /// Brand colour while comfortable; warning colours take over as the window runs low.
    public static func status(_ remainingPercent: Double, brand: Color) -> Color {
        let level = UsageLevel(remainingPercent: remainingPercent)
        return level == .comfortable ? brand : color(for: level)
    }

    public static func color(for level: UsageLevel) -> Color {
        switch level {
        case .comfortable: accent
        case .low: warning
        case .critical: critical
        }
    }
}
