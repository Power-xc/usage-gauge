import Foundation
import UsageGaugeCore

/// Deterministic sample usage for renders; numbers are illustrative, not anyone's account.
enum SampleData {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    static func window(remaining: Double, minutes: Int, resetIn seconds: TimeInterval) -> UsageWindow {
        UsageWindow(usedPercent: 100 - remaining, resetsAt: now.addingTimeInterval(seconds), windowMinutes: minutes)
    }

    static func claude(session: Double, weekly: Double) -> ProviderUsage {
        ProviderUsage(id: "claude", plan: "Max",
                      session: window(remaining: session, minutes: 300, resetIn: 230 * 60),
                      weekly: window(remaining: weekly, minutes: 10080, resetIn: 72 * 3600))
    }

    static func codex(session: Double, weekly: Double) -> ProviderUsage {
        ProviderUsage(id: "codex", plan: "Plus",
                      session: window(remaining: session, minutes: 300, resetIn: 47 * 60),
                      weekly: window(remaining: weekly, minutes: 10080, resetIn: 160 * 3600))
    }

    static func cursor(session: Double, weekly: Double) -> ProviderUsage {
        ProviderUsage(id: "cursor", plan: "Pro",
                      session: window(remaining: session, minutes: 300, resetIn: 130 * 60),
                      weekly: window(remaining: weekly, minutes: 43200, resetIn: 400 * 3600))
    }

    static func extras(scale: Double) -> [ProviderUsage] {
        [
            ProviderUsage(id: "gemini", plan: "Pro",
                          session: window(remaining: 71 * scale, minutes: 1440, resetIn: 9 * 3600),
                          weekly: window(remaining: 88 * scale, minutes: 10080, resetIn: 120 * 3600)),
            cursor(session: 46 * scale, weekly: 53 * scale),
            ProviderUsage(id: "copilot", plan: "Pro",
                          session: window(remaining: 24 * scale, minutes: 1440, resetIn: 15 * 3600),
                          weekly: window(remaining: 62 * scale, minutes: 43200, resetIn: 500 * 3600)),
        ]
    }

    static let still = [claude(session: 94, weekly: 37), codex(session: 8, weekly: 26)]

    /// When the sample numbers were measured; every scene shows this one moment.
    static let measuredAt = now.addingTimeInterval(-10 * 60)

    /// The header's "오후 4:50 기준" for the sample moment.
    static let status: String = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return "\(formatter.string(from: measuredAt)) 기준"
    }()

    /// The menu bar clock at the sample moment, e.g. "1월 15일 (금) 오후 5:00".
    static let menuBarClock: String = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E) a h:mm"
        return formatter.string(from: now)
    }()

    /// The four sample tools of the stills, each stamped with the measuring time.
    static let tools = stamped(still + extras(scale: 1).prefix(2))

    /// A wider line-up for the reel: the stills' tools, then more of the services the usage CLI reads.
    static let lineup = stamped(still + extras(scale: 1) + [
        ProviderUsage(id: "windsurf", session: window(remaining: 63, minutes: 1440, resetIn: 11 * 3600),
                      weekly: window(remaining: 81, minutes: 43200, resetIn: 420 * 3600)),
        ProviderUsage(id: "grok", session: window(remaining: 88, minutes: 120, resetIn: 70 * 60),
                      weekly: window(remaining: 74, minutes: 10080, resetIn: 96 * 3600)),
        ProviderUsage(id: "openrouter", session: window(remaining: 35, minutes: 1440, resetIn: 6 * 3600),
                      weekly: window(remaining: 58, minutes: 43200, resetIn: 300 * 3600)),
    ])

    /// Re-stamps tools with the sample measuring time (for the demo, whose values move).
    static func stamped(_ providers: [ProviderUsage]) -> [ProviderUsage] {
        providers.map { ProviderUsage(id: $0.id, plan: $0.plan, session: $0.session, weekly: $0.weekly, measuredAt: measuredAt) }
    }
}
