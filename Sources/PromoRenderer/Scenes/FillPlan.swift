import Foundation
import UsageGaugeCore

/// How a scene brings its tools up from empty: each tool fills in turn, they hold, then all of
/// them drain together so a loop can start again from empty.
struct FillPlan {
    /// When the first tool starts filling, how long one tool takes and the delay between tools.
    let start: Double
    let duration: Double
    let stagger: Double
    /// When the drain starts and how long it takes.
    let resetAt: Double
    let resetDuration: Double

    /// How full the tool at `index` is, 0...1.
    func amount(at time: Double, index: Int) -> Double {
        let begin = start + stagger * Double(index)
        return Motion.progress(time, from: begin, to: begin + duration)
            * (1 - Motion.progress(time, from: resetAt, to: resetAt + resetDuration))
    }

    /// The tools with every remaining percentage scaled by how full each one is.
    func apply(to providers: [ProviderUsage], at time: Double) -> [ProviderUsage] {
        Self.scale(providers) { amount(at: time, index: $0) }
    }

    /// The tools with each one's remaining percentages scaled by `amount` for its index.
    static func scale(_ providers: [ProviderUsage], by amount: (Int) -> Double) -> [ProviderUsage] {
        providers.enumerated().map { index, provider in
            let amount = amount(index)
            return ProviderUsage(id: provider.id, plan: provider.plan,
                                 session: provider.session.map { scaled($0, by: amount) },
                                 weekly: provider.weekly.map { scaled($0, by: amount) },
                                 errorMessage: provider.errorMessage, measuredAt: provider.measuredAt)
        }
    }

    private static func scaled(_ window: UsageWindow, by amount: Double) -> UsageWindow {
        UsageWindow(usedPercent: 100 - window.remainingPercent * amount, resetsAt: window.resetsAt,
                    windowMinutes: window.windowMinutes)
    }
}
