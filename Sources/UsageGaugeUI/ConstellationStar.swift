import SwiftUI
import UsageGaugeCore

/// One tool as a point on the constellation field: x is its short window's remaining share and y
/// its long window's, both as 0...1 with y growing upward. A tool with a single window sits on the
/// axis of that window.
struct ConstellationStar: Identifiable {
    /// The history looked back this far for where the tool stood, but only trusts a sample that is
    /// at least `minimumTrailAge` old, so a trail is never drawn from noise.
    private static let trailAge: TimeInterval = 3600
    private static let minimumTrailAge: TimeInterval = 600

    let usage: ProviderUsage
    let position: CGPoint
    /// Where the tool stood about an hour ago; nil without history that far back.
    let before: CGPoint?

    var id: String { usage.id }

    /// The tools that report something, in the order given.
    static func stars(of providers: [ProviderUsage], history: UsageHistory, now: Date) -> [ConstellationStar] {
        providers.compactMap { usage in
            guard usage.isAvailable else { return nil }
            let past = (session: pastShare(usage.session, of: usage.id, history, now),
                        long: pastShare(usage.weekly, of: usage.id, history, now))
            let hasTrail = (usage.session == nil || past.session != nil) && (usage.weekly == nil || past.long != nil)
            return ConstellationStar(
                usage: usage,
                position: unit(usage.session?.remainingPercent, usage.weekly?.remainingPercent),
                before: hasTrail ? unit(past.session, past.long) : nil)
        }
    }

    private static func unit(_ short: Double?, _ long: Double?) -> CGPoint {
        CGPoint(x: (short ?? 0) / 100, y: (long ?? 0) / 100)
    }

    /// The remaining share of `window` at the recorded sample closest to an hour ago.
    private static func pastShare(_ window: UsageWindow?, of id: String, _ history: UsageHistory, _ now: Date) -> Double? {
        guard let window else { return nil }
        let target = now.addingTimeInterval(-trailAge)
        let newest = now.addingTimeInterval(-minimumTrailAge)
        return history.points(for: id, window: window, now: now)
            .filter { $0.at <= newest }
            .min { abs($0.at.timeIntervalSince(target)) < abs($1.at.timeIntervalSince(target)) }?
            .remaining
    }
}
