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
    /// Live-status lamp of the dot style.
    public static let signal = Color(red: 255 / 255, green: 90 / 255, blue: 54 / 255)

    public static let primaryText = Color.white
    public static let mutedText = Color.white.opacity(0.62)
    public static let faintText = Color.white.opacity(0.42)
    public static let hairline = Color.white.opacity(0.10)
    public static let track = Color.white.opacity(0.10)

    public static let panelCornerRadius: CGFloat = 22
    public static let panelPadding: CGFloat = 12
    public static let dialSize: CGFloat = 72
    public static let detailWidth: CGFloat = 140

    public static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Large display figures: tight, fixed-width digits that read as type, not as a readout.
    public static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold).monospacedDigit()
    }

    /// Type for labels: the system face, or a monospaced one for the dot and mono styles.
    public static func label(_ size: CGFloat, _ weight: Font.Weight = .regular, style: PanelStyle) -> Font {
        style.isMonospaced ? mono(size, weight) : font(size, weight)
    }

    /// Type for figures and countdowns: rounded digits, or monospaced ones for the dot and mono styles.
    public static func figure(_ size: CGFloat, _ weight: Font.Weight = .semibold, style: PanelStyle) -> Font {
        style.isMonospaced ? mono(size, weight) : number(size, weight)
    }

    public static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Rounded, fixed-width digits, as in Apple's activity and battery readouts.
    public static func number(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    /// Deep signature colour of each tool; any other provider gets its own stable hue at the same depth.
    public static func brand(for providerID: String) -> Color {
        switch providerID {
        case "claude": Color(red: 193 / 255, green: 95 / 255, blue: 60 / 255)
        case "codex", "openai": Color(red: 13 / 255, green: 138 / 255, blue: 104 / 255)
        case "gemini", "antigravity": Color(red: 52 / 255, green: 98 / 255, blue: 214 / 255)
        case "copilot": Color(red: 112 / 255, green: 78 / 255, blue: 226 / 255)
        case "cursor": Color(red: 168 / 255, green: 176 / 255, blue: 192 / 255)
        default: Color(hue: ProviderCatalog.hue(for: providerID), saturation: 0.62, brightness: 0.8)
        }
    }

    /// Warning colour once a window runs low, nil while comfortable. It tints the figures only, so
    /// each tool keeps its own colour on the dial and bar.
    public static func alert(_ remainingPercent: Double) -> Color? {
        let level = UsageLevel(remainingPercent: remainingPercent)
        return level == .comfortable ? nil : color(for: level)
    }

    public static func color(for level: UsageLevel) -> Color {
        switch level {
        case .comfortable: accent
        case .low: warning
        case .critical: critical
        }
    }
}
