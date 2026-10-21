import SwiftUI

/// A list of numbers SwiftUI can interpolate, so a Canvas that draws from several coordinates at
/// once animates between two sets of them. Lists of different length pad the shorter with zeros.
struct AnimatableValues: VectorArithmetic {
    var values: [Double]

    init(_ values: [Double] = []) {
        self.values = values
    }

    static let zero = AnimatableValues()

    static func + (lhs: Self, rhs: Self) -> Self { combine(lhs, rhs, +) }

    static func - (lhs: Self, rhs: Self) -> Self { combine(lhs, rhs, -) }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * rhs }
    }

    var magnitudeSquared: Double {
        values.reduce(0) { $0 + $1 * $1 }
    }

    private static func combine(_ lhs: Self, _ rhs: Self, _ operation: (Double, Double) -> Double) -> Self {
        Self((0..<max(lhs.values.count, rhs.values.count)).map { index in
            operation(index < lhs.values.count ? lhs.values[index] : 0, index < rhs.values.count ? rhs.values[index] : 0)
        })
    }
}
