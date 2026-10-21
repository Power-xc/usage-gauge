import SwiftUI
import UsageGaugeCore

/// A remaining share as a figure in the style's type, turning to the warning colours when low: a
/// display face (iris), LED dots (dot) or monospaced digits (mono). Shared by the shape layouts.
struct ShapeFigure: View {
    private static let monoScale: CGFloat = 0.94
    /// Dot pitch as a share of the figure height: a glyph is seven pitches tall.
    private static let dotPitchShare: CGFloat = 1.0 / 8
    private static let percentScale: CGFloat = 0.55

    let window: UsageWindow?
    /// Height of the digits in points (iris font size).
    let size: CGFloat

    @Environment(\.panelStyle) private var style

    var body: some View {
        let alert = window.flatMap { Theme.alert($0.remainingPercent) }
        let text = window.map { "\($0.displayPercent)" } ?? ResetCountdown.unknown
        switch style {
        case .iris:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(text).font(Theme.display(size)).tracking(-size * 0.025).foregroundStyle(alert ?? Theme.primaryText)
                if window != nil { Text("%").font(Theme.font(size * 0.42, .medium)).foregroundStyle(Theme.mutedText) }
            }
        case .dot:
            let pitch = size * Self.dotPitchShare
            HStack(alignment: .bottom, spacing: pitch) {
                DotMatrixText(text, pitch: pitch, color: alert ?? .white)
                if window != nil { DotMatrixText("%", pitch: pitch * Self.percentScale, color: Theme.mutedText) }
            }
        case .mono:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(text).font(Theme.mono(size * Self.monoScale, .semibold)).foregroundStyle(alert ?? .white)
                if window != nil { Text("%").font(Theme.mono(size * 0.4, .medium)).foregroundStyle(Theme.mutedText) }
            }
        }
    }
}
