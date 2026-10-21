import SwiftUI
import UsageGaugeCore

/// A window's remaining share over its whole period, as unit coordinates for the trend chart:
/// x runs from the window's start to its reset, y from empty (0) to full (1).
struct TrendSeries {
    /// Recording gaps longer than this (the app was closed) break the line instead of bridging it.
    static let gap: TimeInterval = 20 * 60

    /// Runs of connected points, oldest first.
    private(set) var segments: [[CGPoint]]
    /// The latest reading, at now.
    private(set) var head: CGPoint
    /// Where the burn rate leads from now: the empty point, or the reset when it lasts.
    private(set) var projection: CGPoint?
    let burnRate: Double?
    let projectedEmpty: Date?
    /// How much time the recorded points cover.
    let recordedSpan: TimeInterval

    /// The series with its latest reading and projection end moved, for the frames in between two readings.
    func moving(head newHead: CGPoint, projectionEnd: CGPoint?) -> TrendSeries {
        var moved = self
        if var run = moved.segments.last, !run.isEmpty {
            run[run.count - 1] = newHead
            moved.segments[moved.segments.count - 1] = run
        }
        moved.head = newHead
        moved.projection = projection == nil ? nil : projectionEnd
        return moved
    }

    init?(id: String, window: UsageWindow, history: UsageHistory, now: Date) {
        guard let resetsAt = window.resetsAt, let minutes = window.windowMinutes, minutes > 0 else { return nil }
        let length = Double(minutes) * 60
        let start = resetsAt.addingTimeInterval(-length)
        func unit(_ date: Date, _ remaining: Double) -> CGPoint {
            CGPoint(x: min(1, max(0, date.timeIntervalSince(start) / length)), y: remaining / 100)
        }

        var points = history.points(for: id, window: window, now: now)
        recordedSpan = (points.last?.at).flatMap { last in points.first.map { last.timeIntervalSince($0.at) } } ?? 0
        if points.last.map({ $0.at < now }) ?? true {
            points.append(UsagePoint(at: now, remaining: window.remainingPercent))
        }
        var runs: [[CGPoint]] = []
        var previous: Date?
        for point in points {
            if let previous, point.at.timeIntervalSince(previous) <= Self.gap {
                runs[runs.count - 1].append(unit(point.at, point.remaining))
            } else {
                runs.append([unit(point.at, point.remaining)])
            }
            previous = point.at
        }
        segments = runs
        head = unit(now, window.remainingPercent)

        let rate = history.burnRate(for: id, window: window, now: now)
        burnRate = rate
        projectedEmpty = history.projectedEmpty(for: id, window: window, now: now)
        if let rate {
            let end = projectedEmpty ?? resetsAt
            let left = max(0, window.remainingPercent - rate * end.timeIntervalSince(now) / 3600)
            projection = unit(end, left)
        } else {
            projection = nil
        }
    }
}
