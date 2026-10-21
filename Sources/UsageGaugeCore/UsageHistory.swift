import Foundation

/// The remaining share of a provider's windows at one moment.
public struct UsageSample: Codable, Equatable, Sendable {
    public let at: Date
    /// Remaining % of the provider's short window at `at`.
    public let session: Double?
    /// Remaining % of the provider's long window at `at`.
    public let long: Double?

    public init(at: Date, session: Double?, long: Double?) {
        self.at = at
        self.session = session
        self.long = long
    }

    /// Finite, in range, and carrying at least one reading.
    fileprivate var isValid: Bool {
        let readings = [session, long].compactMap { $0 }
        return at.timeIntervalSince1970.isFinite && !readings.isEmpty
            && readings.allSatisfy { $0.isFinite && (0...100).contains($0) }
    }
}

/// One reading of a window's remaining share.
public struct UsagePoint: Equatable, Sendable {
    public let at: Date
    public let remaining: Double

    public init(at: Date, remaining: Double) {
        self.at = at
        self.remaining = remaining
    }
}

/// A short record of how each provider's windows drained, kept for the trend and burn-rate views.
/// Holds only provider ids, timestamps and percentages.
public struct UsageHistory: Codable, Equatable, Sendable {
    static let retention: TimeInterval = 26 * 3600
    static let capacity = 1000
    static let minimumSpacing: TimeInterval = 50
    static let burnLookback: TimeInterval = 3600
    static let minimumBurnSpan: TimeInterval = 600
    /// Windows longer than this are a provider's long window; shorter ones its short window.
    static let longWindowMinutes = 1440

    public private(set) var samples: [String: [UsageSample]]

    public init() {
        samples = [:]
    }

    /// Sorts, dedupes and caps each series and drops invalid samples. It has no clock, so unlike
    /// decoding it keeps samples of any date.
    public init(samples: [String: [UsageSample]]) {
        self.samples = samples.mapValues(Self.sanitized).filter { !$0.value.isEmpty }
    }

    public init(from decoder: Decoder) throws {
        let stored = try decoder.container(keyedBy: CodingKeys.self).decode([String: [Lossy]].self, forKey: .samples)
        let present = Date()
        let kept = stored.mapValues { $0.compactMap(\.sample).filter { $0.at <= present } }
        self.init(samples: kept)
    }

    /// Appends one sample per available provider (skipping one whose last sample is under 50 s
    /// old) and keeps 26 hours, at most 1 000 per provider.
    public mutating func record(_ providers: [ProviderUsage], at now: Date) {
        for usage in providers where usage.isAvailable {
            var series = samples[usage.id] ?? []
            if let last = series.last, now.timeIntervalSince(last.at) < Self.minimumSpacing { continue }
            series.append(UsageSample(at: now, session: usage.session?.remainingPercent, long: usage.weekly?.remainingPercent))
            samples[usage.id] = series
        }
        let oldest = now.addingTimeInterval(-Self.retention)
        samples = samples.mapValues { Self.sanitized($0.filter { $0.at >= oldest }) }.filter { !$0.value.isEmpty }
    }

    /// Samples of `id` inside `window`'s current period (from resetsAt − windowMinutes to now),
    /// oldest first. Empty when the window has no reset time or length.
    public func samples(for id: String, in window: UsageWindow, now: Date) -> [UsageSample] {
        guard let period = Self.period(of: window) else { return [] }
        return (samples[id] ?? []).filter { $0.at >= period.start && $0.at <= now }
    }

    /// The readings of `window` within its current period, oldest first. The window's own series is
    /// told apart by its length; a provider that reports only one window has it in either slot.
    public func points(for id: String, window: UsageWindow, now: Date) -> [UsagePoint] {
        let inPeriod = samples(for: id, in: window, now: now)
        let isLong = (window.windowMinutes ?? 0) > Self.longWindowMinutes
        let preferred: KeyPath<UsageSample, Double?> = isLong ? \.long : \.session
        let other: KeyPath<UsageSample, Double?> = isLong ? \.session : \.long
        for path in [preferred, other] {
            let points = inPeriod.compactMap { sample in sample[keyPath: path].map { UsagePoint(at: sample.at, remaining: $0) } }
            if !points.isEmpty { return points }
        }
        return []
    }

    /// % of `window` used per hour over the last 60 min of its current period; nil with under
    /// 10 min of data or nothing used.
    public func burnRate(for id: String, window: UsageWindow, now: Date) -> Double? {
        let recent = points(for: id, window: window, now: now).filter { $0.at >= now.addingTimeInterval(-Self.burnLookback) }
        guard let first = recent.first, let last = recent.last else { return nil }
        let span = last.at.timeIntervalSince(first.at)
        let used = Self.drops(in: recent)
        guard span >= Self.minimumBurnSpan, used > 0 else { return nil }
        return used / (span / 3600)
    }

    /// When `window` runs out at `burnRate`; nil when there is no rate or it lasts past the reset.
    public func projectedEmpty(for id: String, window: UsageWindow, now: Date) -> Date? {
        guard let rate = burnRate(for: id, window: window, now: now), let resetsAt = window.resetsAt else { return nil }
        let empty = now.addingTimeInterval(window.remainingPercent / rate * 3600)
        return empty < resetsAt ? empty : nil
    }

    /// `slices` equal slices of the window's period from start to reset: % used in each (sum of
    /// drops between consecutive samples, rises ignored); 0 for a past slice without drops; nil
    /// for slices after now.
    public func usedPerSlice(for id: String, window: UsageWindow, now: Date, slices: Int) -> [Double?] {
        guard let grid = SliceGrid(window: window, now: now, slices: slices) else { return [] }
        let points = points(for: id, window: window, now: now)
        var used = [Double](repeating: 0, count: slices)
        for (before, after) in zip(points, points.dropFirst()) {
            used[grid.index(of: after.at)] += max(0, before.remaining - after.remaining)
        }
        return (0..<slices).map { grid.hasStarted($0) ? used[$0] : nil }
    }

    /// Same slicing: remaining % at the end of each slice (last sample in it, carried forward from
    /// the previous slice when it has none); nil before the first sample and after now.
    public func remainingPerSlice(for id: String, window: UsageWindow, now: Date, slices: Int) -> [Double?] {
        guard let grid = SliceGrid(window: window, now: now, slices: slices) else { return [] }
        var lastIn = [Double?](repeating: nil, count: slices)
        for point in points(for: id, window: window, now: now) { lastIn[grid.index(of: point.at)] = point.remaining }
        var carried: Double?
        return (0..<slices).map { slice in
            carried = lastIn[slice] ?? carried
            return grid.hasStarted(slice) ? carried : nil
        }
    }

    // MARK: - Helpers

    private enum CodingKeys: String, CodingKey { case samples }

    /// Decodes a sample or nothing, so one damaged entry does not cost the whole file.
    private struct Lossy: Decodable {
        let sample: UsageSample?
        init(from decoder: Decoder) throws {
            sample = try? UsageSample(from: decoder)
        }
    }

    private static func sanitized(_ series: [UsageSample]) -> [UsageSample] {
        var byTime: [Date: UsageSample] = [:]
        for sample in series where sample.isValid { byTime[sample.at] = sample }
        return byTime.values.sorted { $0.at < $1.at }.suffix(capacity)
    }

    private static func period(of window: UsageWindow) -> (start: Date, end: Date)? {
        guard let resetsAt = window.resetsAt, let minutes = window.windowMinutes, minutes > 0 else { return nil }
        return (resetsAt.addingTimeInterval(-Double(minutes) * 60), resetsAt)
    }

    private static func drops(in points: [UsagePoint]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { $0 + max(0, $1.0.remaining - $1.1.remaining) }
    }

    /// A window's period cut into equal slices.
    private struct SliceGrid {
        let start: Date
        let length: TimeInterval
        let count: Int
        let now: Date

        init?(window: UsageWindow, now: Date, slices: Int) {
            guard slices > 0, let period = UsageHistory.period(of: window) else { return nil }
            start = period.start
            length = period.end.timeIntervalSince(period.start) / Double(slices)
            count = slices
            self.now = now
        }

        func index(of date: Date) -> Int {
            min(count - 1, max(0, Int(date.timeIntervalSince(start) / length)))
        }

        func hasStarted(_ slice: Int) -> Bool {
            start.addingTimeInterval(Double(slice) * length) <= now
        }
    }
}
