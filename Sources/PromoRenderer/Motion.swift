import Foundation

/// Small timeline helpers. `progress` maps a time window to 0...1 with ease-in-out.
enum Motion {
    static func progress(_ time: Double, from start: Double, to end: Double) -> Double {
        guard end > start else { return time >= end ? 1 : 0 }
        let linear = min(1, max(0, (time - start) / (end - start)))
        return linear * linear * (3 - 2 * linear)
    }

    static func mix(_ from: Double, _ to: Double, _ amount: Double) -> Double {
        from + (to - from) * amount
    }

    /// Fades in over `fade` seconds at `start` and out over `fade` seconds before `end`.
    static func visibility(_ time: Double, start: Double, end: Double, fade: Double = 0.5) -> Double {
        min(progress(time, from: start, to: start + fade), 1 - progress(time, from: end - fade, to: end))
    }
}
