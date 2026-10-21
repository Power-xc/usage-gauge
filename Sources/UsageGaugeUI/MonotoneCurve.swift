import SwiftUI

/// A smooth curve through points of increasing x that never leaves the range of its neighbours:
/// a monotone cubic (Fritsch–Butland tangents), so a line chart of a share stays between 0 and
/// 100 and shows no overshoot where the data turns flat.
struct MonotoneCurve {
    private static let samplingStep: CGFloat = 0.5

    private let points: [CGPoint]
    private let slopes: [CGFloat]

    init(_ source: [CGPoint]) {
        var kept: [CGPoint] = []
        for point in source {
            guard let last = kept.last else { kept.append(point); continue }
            if point.x > last.x { kept.append(point) } else if point.x == last.x { kept[kept.count - 1] = point }
        }
        points = kept
        slopes = Self.tangents(of: kept)
    }

    var start: CGPoint? { points.first }
    var end: CGPoint? { points.last }

    var path: Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for index in 0..<max(points.count - 1, 0) {
            let a = points[index], b = points[index + 1]
            let third = (b.x - a.x) / 3
            path.addCurve(to: b, control1: CGPoint(x: a.x + third, y: a.y + slopes[index] * third),
                          control2: CGPoint(x: b.x - third, y: b.y - slopes[index + 1] * third))
        }
        return path
    }

    /// The curve closed down to `baseline`: the area under a line.
    func area(down baseline: CGFloat) -> Path {
        var area = path
        guard let first = points.first, let last = points.last else { return area }
        area.addLine(to: CGPoint(x: last.x, y: baseline))
        area.addLine(to: CGPoint(x: first.x, y: baseline))
        area.closeSubpath()
        return area
    }

    /// Height of the curve at `x`, which must lie between its ends.
    func y(at x: CGFloat) -> CGFloat {
        guard let index = points.indices.dropLast().last(where: { points[$0].x <= x }) else { return points.first?.y ?? 0 }
        let a = points[index], b = points[index + 1]
        let width = b.x - a.x
        let t = min(1, max(0, (x - a.x) / width))
        let t2 = t * t, t3 = t2 * t
        return (2 * t3 - 3 * t2 + 1) * a.y + (t3 - 2 * t2 + t) * width * slopes[index]
            + (-2 * t3 + 3 * t2) * b.y + (t3 - t2) * width * slopes[index + 1]
    }

    /// Points along the curve `spacing` apart measured on the curve itself, from its start.
    func evenlySpaced(_ spacing: CGFloat) -> [CGPoint] {
        guard let first = points.first, let last = points.last else { return [] }
        var spaced = [first]
        var previous = first
        var travelled: CGFloat = 0
        var x = first.x + Self.samplingStep
        while x <= last.x {
            let current = CGPoint(x: x, y: y(at: x))
            travelled += hypot(current.x - previous.x, current.y - previous.y)
            if travelled >= spacing {
                spaced.append(current)
                travelled = 0
            }
            previous = current
            x += Self.samplingStep
        }
        return spaced
    }

    /// Tangent slopes that keep each piece monotone: zero at turning points, a weighted harmonic
    /// mean of the neighbouring secants elsewhere.
    private static func tangents(of points: [CGPoint]) -> [CGFloat] {
        guard points.count > 1 else { return points.map { _ in 0 } }
        let widths = zip(points, points.dropFirst()).map { $1.x - $0.x }
        let secants = zip(points, points.dropFirst()).map { ($1.y - $0.y) / ($1.x - $0.x) }
        var slopes = [secants[0]]
        for index in 1..<(points.count - 1) {
            let before = secants[index - 1], after = secants[index]
            guard before * after > 0 else { slopes.append(0); continue }
            let (wb, wa) = (widths[index - 1], widths[index])
            slopes.append(3 * (wb + wa) / ((2 * wa + wb) / before + (wa + 2 * wb) / after))
        }
        slopes.append(secants[secants.count - 1])
        return slopes
    }
}
