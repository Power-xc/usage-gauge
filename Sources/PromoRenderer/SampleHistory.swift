import Foundation
import UsageGaugeCore

extension SampleData {
    private struct Profile {
        /// Short-window remaining % as (minutes before `now`, remaining) keyframes, oldest first,
        /// ending at the tool's current value in the sample usage. Steep stretches are bursts,
        /// flat ones quiet spells.
        let session: [(ago: Int, remaining: Double)]
        /// Long-window remaining % now; the series eases down to it.
        let longNow: Double
    }

    /// Minutes between samples, a little under the app's two-minute fetch rhythm.
    private static let sampleStep = 3
    private static let longDrift = 3.0

    private static let profiles: [String: Profile] = [
        "claude": Profile(session: [(70, 100), (46, 100), (40, 96), (21, 96), (15, 94), (0, 94)], longNow: 37),
        "codex": Profile(session: [(253, 100), (200, 66), (150, 52), (110, 52), (85, 30), (50, 22), (20, 19), (8, 9), (0, 8)], longNow: 26),
        "gemini": Profile(session: [(900, 100), (780, 94), (700, 82), (560, 82), (500, 72), (200, 72), (0, 71)], longNow: 88),
        "cursor": Profile(session: [(170, 100), (140, 90), (105, 68), (95, 64), (60, 60), (30, 52), (0, 46)], longNow: 53),
        "copilot": Profile(session: [(540, 100), (470, 90), (300, 90), (240, 62), (120, 62), (60, 40), (0, 24)], longNow: 62),
    ]

    /// Codex's session 25 minutes on: the same keyframes, 25 minutes older, then the drain from 8%
    /// down to 1%. At about 19% an hour that runs out in three minutes.
    private static let laterCodex = Profile(
        session: [(278, 100), (225, 66), (175, 52), (135, 52), (110, 30), (75, 22), (45, 19), (33, 9), (25, 8), (0, 1)],
        longNow: 25)

    /// Deterministic sample histories for the sample tools, relative to `SampleData.now`.
    static let history = recorded(profiles)

    /// The histories behind `nearlyOut`.
    static let nearlyOutHistory = recorded(profiles.merging(["codex": laterCodex]) { $1 })

    private static func recorded(_ profiles: [String: Profile]) -> UsageHistory {
        UsageHistory(samples: profiles.mapValues { profile in
            let oldest = profile.session[0].ago
            return stride(from: oldest, through: 0, by: -sampleStep).map { ago in
                UsageSample(at: now.addingTimeInterval(-Double(ago) * 60),
                            session: interpolated(profile.session, at: ago).rounded(),
                            long: (profile.longNow + longDrift * Double(ago) / Double(oldest)).rounded())
            }
        })
    }

    private static func interpolated(_ keyframes: [(ago: Int, remaining: Double)], at ago: Int) -> Double {
        guard let next = keyframes.firstIndex(where: { $0.ago <= ago }) ?? keyframes.indices.last else { return 100 }
        guard next > 0 else { return keyframes[0].remaining }
        let from = keyframes[next - 1], to = keyframes[next]
        let t = Double(from.ago - ago) / Double(from.ago - to.ago)
        return from.remaining + (to.remaining - from.remaining) * t
    }
}
