import SwiftUI
import UsageGaugeCore

/// A large figure in the style's type with a small "%" after it: a display face (iris), LED dots
/// (dot) or monospaced digits (mono). Every layout's large figures go through here, so they share
/// one scale.
struct StyleFigure: View {
    /// Dot pitch as a share of the size: a glyph is seven pitches tall.
    private static let dotPitchShare: CGFloat = 0.1125
    private static let monoScale: CGFloat = 0.94
    private static let dotPercentScale: CGFloat = 0.55

    let text: String
    let showsPercent: Bool
    let color: Color
    /// Height of the digits in points (the iris font size).
    let size: CGFloat

    @Environment(\.panelStyle) private var style

    var body: some View {
        switch style {
        case .iris:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(text).font(Theme.display(size)).tracking(-size * 0.025).foregroundStyle(color)
                if showsPercent { Text("%").font(Theme.font(size * 0.44, .medium)).foregroundStyle(Theme.mutedText) }
            }
        case .dot:
            let pitch = size * Self.dotPitchShare
            HStack(alignment: .bottom, spacing: pitch) {
                DotMatrixText(text, pitch: pitch, color: color)
                if showsPercent { DotMatrixText("%", pitch: pitch * Self.dotPercentScale, color: Theme.mutedText) }
            }
        case .mono:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(text).font(Theme.mono(size * Self.monoScale, .semibold)).foregroundStyle(color)
                if showsPercent { Text("%").font(Theme.mono(size * 0.41, .medium)).foregroundStyle(Theme.mutedText) }
            }
        }
    }
}

/// A window's remaining share as a `StyleFigure`, in the warning colours when low and "–" when the
/// window is unknown.
struct PercentFigure: View {
    let window: UsageWindow?
    /// Height of the digits in points (the iris font size).
    let size: CGFloat

    var body: some View {
        StyleFigure(text: window.map { "\($0.displayPercent)" } ?? ResetCountdown.unknown, showsPercent: window != nil,
                    color: window.flatMap { Theme.alert($0.remainingPercent) } ?? Theme.primaryText, size: size)
    }
}
