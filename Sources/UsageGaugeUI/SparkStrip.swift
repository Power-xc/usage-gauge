import SwiftUI

/// A strip of thin vertical bars over the window's period, each as tall as what was left at that
/// point: the tool's colour for the past, a contrasting tick at now and faint baseline marks for
/// what is still to come. Drawn as flat rounded bars (iris), columns of dots
/// (dot) or 1 pt lines (mono).
struct SparkStrip: View, Animatable {
    static let height: CGFloat = 24

    private static let dotPitch: CGFloat = 3.6
    private static let dotSize: CGFloat = 2.2
    private static let dotsAcross = 2
    private static let softWidth: CGFloat = 3
    private static let softPitch: CGFloat = 6
    private static let monoWidth: CGFloat = 1
    private static let monoPitch: CGFloat = 4
    private static let dotColumnPitch: CGFloat = 7.2
    private static let tickWidth: CGFloat = 1.6
    private static let baselineOpacity = 0.16
    private static let minHeight: CGFloat = 1.5

    /// Slices that fit `width`, which the layout asks the history for.
    static func slices(width: CGFloat, style: PanelStyle) -> Int {
        let pitch: CGFloat
        switch style {
        case .iris: pitch = softPitch
        case .dot: pitch = dotColumnPitch
        case .mono: pitch = monoPitch
        }
        return Int(width / pitch)
    }

    /// Remaining % per slice; nil before the first reading and after now.
    var values: [Double?]
    /// Slice that holds now.
    let nowIndex: Int?
    let tint: Color

    @Environment(\.panelStyle) private var style

    var animatableData: SliceValues {
        get { SliceValues(values) }
        set { values = newValue.slices }
    }

    var body: some View {
        Canvas { canvas, size in
            let pitch = (size.width - barWidth) / CGFloat(max(values.count - 1, 1))
            var bars = Path(), marks = Path(), tick = Path()
            for (index, value) in values.enumerated() {
                let rect = columnRect(index: index, pitch: pitch, height: size.height)
                if index == nowIndex {
                    addTick(into: &tick, at: rect.midX, height: size.height)
                } else if let value {
                    add(into: &bars, rect: rect, fraction: value / 100, height: size.height)
                } else {
                    add(into: &marks, rect: rect, fraction: 0, height: size.height)
                }
            }
            canvas.fill(marks, with: .color(.white.opacity(Self.baselineOpacity)))
            canvas.fill(bars, with: .color(tint))
            canvas.fill(tick, with: .color(.white.opacity(0.95)))
        }
        .frame(height: Self.height)
    }

    /// Width of one bar; the first bar starts at the strip's left edge and the last ends at its right,
    /// in line with the window bar above.
    private var barWidth: CGFloat {
        switch style {
        case .iris: Self.softWidth
        case .dot: Self.dotPitch * CGFloat(Self.dotsAcross - 1) + Self.dotSize
        case .mono: Self.monoWidth
        }
    }

    private func columnRect(index: Int, pitch: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: CGFloat(index) * pitch, y: 0, width: barWidth, height: height)
    }

    /// The marker of now: a solid line, or a column of larger dots in the dot style.
    private func addTick(into path: inout Path, at x: CGFloat, height: CGFloat) {
        if style == .dot {
            for row in 0..<Int(height / Self.dotPitch) {
                let size = Self.dotSize * 1.3
                path.addEllipse(in: CGRect(x: x - size / 2, y: height - CGFloat(row) * Self.dotPitch - Self.dotSize, width: size, height: size))
            }
        } else {
            path.addRoundedRect(in: CGRect(x: x - Self.tickWidth / 2, y: 0, width: Self.tickWidth, height: height),
                                cornerSize: CGSize(width: 0.8, height: 0.8))
        }
    }

    /// Adds one column filled to `fraction` of the height; zero draws the baseline mark.
    private func add(into path: inout Path, rect: CGRect, fraction: Double, height: CGFloat) {
        let filled = max(Self.minHeight, height * fraction)
        switch style {
        case .iris:
            path.addRoundedRect(in: CGRect(x: rect.minX, y: height - filled, width: rect.width, height: filled),
                                cornerSize: CGSize(width: rect.width / 2, height: rect.width / 2))
        case .dot:
            let rows = Int(height / Self.dotPitch)
            let lit = fraction > 0 ? max(1, Int((fraction * Double(rows)).rounded())) : 1
            for row in 0..<lit {
                for across in 0..<Self.dotsAcross {
                    path.addEllipse(in: CGRect(x: rect.minX + CGFloat(across) * Self.dotPitch,
                                               y: height - CGFloat(row) * Self.dotPitch - Self.dotSize,
                                               width: Self.dotSize, height: Self.dotSize))
                }
            }
        case .mono:
            path.addRect(CGRect(x: rect.minX, y: height - filled, width: rect.width, height: filled))
        }
    }
}
