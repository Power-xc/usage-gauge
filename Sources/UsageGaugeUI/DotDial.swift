import SwiftUI

/// Dial in the dot-matrix style: a ring of radial dot columns lit for the remaining share, its
/// outer dots and leading column in the tool's colour, and an inner dotted circle that doubles as
/// the clock — the elapsed part of the window lit, a dot in the tool's colour at now. Lit dots
/// twinkle faintly, like an LED panel.
public struct DotDial: View {
    let remainingPercent: Double
    let elapsedFraction: Double?
    let color: Color
    let frozenAt: TimeInterval?

    private static let frameInterval: TimeInterval = 1.0 / 12
    /// Radial dot columns per point of radius, rounded to whole quarters of the ring.
    private static let columnsPerPoint = 1.4
    private static let columnRadii = [0.78, 0.87, 0.96]
    private static let clockRadius = 0.64
    private static let clockDotsPerPoint = 1.1

    public init(remainingPercent: Double, elapsedFraction: Double?, color: Color, frozenAt: TimeInterval? = nil) {
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.elapsedFraction = elapsedFraction.map { min(1, max(0, $0)) }
        self.color = color
        self.frozenAt = frozenAt
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: Self.frameInterval, paused: frozenAt != nil)) { context in
            let time = frozenAt ?? context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                draw(in: canvas, size: size, time: time.truncatingRemainder(dividingBy: 3600))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func draw(in canvas: GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = min(size.width, size.height) / 2
        let dot = max(1, outer * 0.052)
        drawColumns(in: canvas, center: center, outer: outer, dot: dot, time: time)
        drawClock(in: canvas, center: center, radius: outer * Self.clockRadius, outer: outer, dot: dot)
    }

    private func drawColumns(in canvas: GraphicsContext, center: CGPoint, outer: Double, dot: Double, time: Double) {
        let columns = max(24, Int(outer * Self.columnsPerPoint / 4) * 4)
        let litColumns = Int((remainingPercent / 100 * Double(columns)).rounded())
        var dim = Path(), lit = Path(), tinted = Path(), twinkle = Path()
        for column in 0..<columns {
            let angle = Double(column) / Double(columns) * 2 * .pi - .pi / 2
            let isLit = column < litColumns
            let isHead = isLit && column == litColumns - 1
            for (row, radius) in Self.columnRadii.enumerated() {
                let rect = dotRect(at: point(center, outer * radius, angle), size: dot)
                if !isLit {
                    dim.addEllipse(in: rect)
                } else if isHead || row == Self.columnRadii.count - 1 {
                    tinted.addEllipse(in: rect)
                } else if noise(Double(column * 3 + row) + Double(Int(time * 3))) > 0.86 {
                    twinkle.addEllipse(in: rect)
                } else {
                    lit.addEllipse(in: rect)
                }
            }
        }
        canvas.fill(dim, with: .color(.white.opacity(0.13)))
        canvas.fill(lit, with: .color(.white.opacity(0.9)))
        canvas.fill(twinkle, with: .color(.white.opacity(0.45)))
        canvas.fill(tinted, with: .color(color))
    }

    /// Dotted inner circle: elapsed dots lit from 12 o'clock, the rest faint, and a larger dot in
    /// the tool's colour at now.
    private func drawClock(in canvas: GraphicsContext, center: CGPoint, radius: Double, outer: Double, dot: Double) {
        let count = max(24, Int(outer * Self.clockDotsPerPoint / 4) * 4)
        var passed = Path(), ahead = Path()
        for index in 0..<count {
            let share = Double(index) / Double(count)
            let rect = dotRect(at: point(center, radius, share * 2 * .pi - .pi / 2), size: dot * 0.8)
            if let elapsedFraction, share < elapsedFraction { passed.addEllipse(in: rect) } else { ahead.addEllipse(in: rect) }
        }
        canvas.fill(ahead, with: .color(.white.opacity(0.18)))
        canvas.fill(passed, with: .color(.white.opacity(0.7)))
        guard let elapsedFraction else { return }
        let now = point(center, radius, elapsedFraction * 2 * .pi - .pi / 2)
        canvas.fill(Path(ellipseIn: dotRect(at: now, size: dot * 2.1)), with: .color(color))
    }

    private func dotRect(at center: CGPoint, size: Double) -> CGRect {
        CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
    }

    private func point(_ center: CGPoint, _ radius: Double, _ angle: Double) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    private func noise(_ seed: Double) -> Double {
        let value = sin(seed * 12.9898 + 78.233) * 43758.5453
        return value - value.rounded(.down)
    }
}

/// The long window as a two-row strip of dots: lit for the remaining share, the leading column in
/// the tool's colour.
public struct DotBar: View {
    let remainingPercent: Double
    let color: Color

    private static let pitch: CGFloat = 3.6
    private static let dot: CGFloat = 1.9
    private static let rows = 2

    public init(remainingPercent: Double, color: Color) {
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.color = color
    }

    public var body: some View {
        Canvas { canvas, size in
            let columns = Int(size.width / Self.pitch)
            let lit = Int((remainingPercent / 100 * Double(columns)).rounded())
            var dim = Path(), bright = Path(), head = Path()
            for column in 0..<columns {
                for row in 0..<Self.rows {
                    let rect = CGRect(x: Double(column) * Self.pitch, y: Double(row) * Self.pitch,
                                      width: Self.dot, height: Self.dot)
                    if column >= lit { dim.addEllipse(in: rect) } else if column == lit - 1 { head.addEllipse(in: rect) } else { bright.addEllipse(in: rect) }
                }
            }
            canvas.fill(dim, with: .color(.white.opacity(0.13)))
            canvas.fill(bright, with: .color(.white.opacity(0.88)))
            canvas.fill(head, with: .color(color))
        }
        .frame(height: Self.pitch * CGFloat(Self.rows - 1) + Self.dot)
    }
}

/// Figures drawn on a 5 × 7 dot grid, as on an LED display. Digits, "%" and "–" are supported;
/// anything else is left blank.
public struct DotMatrixText: View {
    let text: String
    let pitch: CGFloat
    let color: Color

    private static let columns = 5
    private static let rows = 7
    /// Dot diameter as a share of the pitch: large enough to read as type, small enough to stay dots.
    private static let dotShare: CGFloat = 0.86
    private static let glyphs: [Character: [String]] = [
        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
        "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
        "%": ["11000", "11001", "00010", "00100", "01000", "10011", "00011"],
        "–": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    ]

    /// - Parameter pitch: distance between dot centres; a glyph is 5 pitches wide and 7 tall.
    public init(_ text: String, pitch: CGFloat, color: Color) {
        self.text = text
        self.pitch = pitch
        self.color = color
    }

    public var body: some View {
        let characters = Array(text)
        let width = CGFloat(characters.count * (Self.columns + 1) - 1) * pitch
        Canvas { canvas, _ in
            var dots = Path()
            for (index, character) in characters.enumerated() {
                guard let glyph = Self.glyphs[character] else { continue }
                let left = CGFloat(index * (Self.columns + 1)) * pitch
                for (row, line) in glyph.enumerated() {
                    for (column, bit) in line.enumerated() where bit == "1" {
                        dots.addEllipse(in: CGRect(x: left + CGFloat(column) * pitch, y: CGFloat(row) * pitch,
                                                   width: pitch * Self.dotShare, height: pitch * Self.dotShare))
                    }
                }
            }
            canvas.fill(dots, with: .color(color))
        }
        .frame(width: width, height: CGFloat(Self.rows) * pitch)
    }
}
