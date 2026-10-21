import SwiftUI

/// Per-slice values of a history chart in a form SwiftUI can interpolate, so a canvas that draws
/// them animates when a new reading changes them. A slice without a value (before the first reading
/// or after now) is kept as presence, which flips at the half-way point.
struct SliceValues: VectorArithmetic {
    var values: [Double]
    var presence: [Double]

    init(_ source: [Double?]) {
        values = source.map { $0 ?? 0 }
        presence = source.map { $0 == nil ? 0 : 1 }
    }

    private init(values: [Double], presence: [Double]) {
        self.values = values
        self.presence = presence
    }

    var slices: [Double?] {
        zip(values, presence).map { $1 > 0.5 ? $0 : nil }
    }

    static var zero: SliceValues { SliceValues(values: [], presence: []) }

    static func + (lhs: SliceValues, rhs: SliceValues) -> SliceValues {
        SliceValues(values: combine(lhs.values, rhs.values, +), presence: combine(lhs.presence, rhs.presence, +))
    }

    static func - (lhs: SliceValues, rhs: SliceValues) -> SliceValues {
        SliceValues(values: combine(lhs.values, rhs.values, -), presence: combine(lhs.presence, rhs.presence, -))
    }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * rhs }
        presence = presence.map { $0 * rhs }
    }

    var magnitudeSquared: Double {
        values.reduce(0) { $0 + $1 * $1 } + presence.reduce(0) { $0 + $1 * $1 }
    }

    /// Element-wise, the shorter side counting as zeros.
    private static func combine(_ a: [Double], _ b: [Double], _ operation: (Double, Double) -> Double) -> [Double] {
        (0..<max(a.count, b.count)).map { operation($0 < a.count ? a[$0] : 0, $0 < b.count ? b[$0] : 0) }
    }
}
