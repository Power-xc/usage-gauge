import Foundation

/// The remaining share of a provider's windows at one moment.
public struct UsageSample: Codable, Equatable, Sendable {
    public let at: Date
    /// Remaining % of the provider's short window at `at`.
    public let session: Double?
    /// Remaining % of the provider's long window at `at`.
    public let long: Double?
    /// Lengths of the two windows when recorded, so a query can tell which series belongs to the
    /// window it asks about. Absent in samples written before they were kept.
    public let sessionMinutes: Int?
    public let longMinutes: Int?

    public init(at: Date, session: Double?, long: Double?, sessionMinutes: Int? = nil, longMinutes: Int? = nil) {
        self.at = at
        self.session = session
        self.long = long
        self.sessionMinutes = sessionMinutes
        self.longMinutes = longMinutes
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
    /// For samples without window lengths: windows longer than this are taken for the long one.
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
    /// old) and keeps 26 hours, at most 1 000 per provider. A sample is dated when CodexBar
    /// measured it, since it may serve cached numbers, and read as of then, so a window whose reset
    /// had already passed counts as full instead of carrying its old share into the new period.
    public mutating func record(_ providers: [ProviderUsage], at now: Date) {
        for usage in providers where usage.isAvailable {
            let measured = min(usage.measuredAt ?? now, now)
            var series = samples[usage.id] ?? []
            if let last = series.last, measured.timeIntervalSince(last.at) < Self.minimumSpacing { continue }
            let reading = usage.resolved(at: measured)
            series.append(UsageSample(at: measured, session: reading.session?.remainingPercent,
                                      long: reading.weekly?.remainingPercent,
                                      sessionMinutes: reading.session?.windowMinutes, longMinutes: reading.weekly?.windowMinutes))
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

    /// The readings of `window` within its current period, oldest first.
    public func points(for id: String, window: UsageWindow, now: Date) -> [UsagePoint] {
        let inPeriod = samples(for: id, in: window, now: now)
        for path in Self.series(of: window, in: inPeriod) {
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

    /// Which series holds `window`: the one recorded with the same length. Older samples carry no
    /// lengths; then a window longer than a day is taken for the long one. The other series is the
    /// fallback, for a provider that reports a single window in either slot.
    private static func series(of window: UsageWindow, in samples: [UsageSample]) -> [KeyPath<UsageSample, Double?>] {
        if let minutes = window.windowMinutes {
            if samples.contains(where: { $0.sessionMinutes == minutes }) { return [\.session] }
            if samples.contains(where: { $0.longMinutes == minutes }) { return [\.long] }
        }
        return (window.windowMinutes ?? 0) > longWindowMinutes ? [\.long, \.session] : [\.session, \.long]
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
