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

    static func extras(scale: Double) -> [ProviderUsage] {
        [
            ProviderUsage(id: "gemini", plan: "Pro",
                          session: window(remaining: 71 * scale, minutes: 1440, resetIn: 9 * 3600),
                          weekly: window(remaining: 88 * scale, minutes: 10080, resetIn: 120 * 3600)),
            ProviderUsage(id: "cursor", plan: "Pro",
                          session: window(remaining: 46 * scale, minutes: 300, resetIn: 130 * 60),
                          weekly: window(remaining: 53 * scale, minutes: 43200, resetIn: 400 * 3600)),
            ProviderUsage(id: "copilot", plan: "Pro",
                          session: window(remaining: 24 * scale, minutes: 1440, resetIn: 15 * 3600),
                          weekly: window(remaining: 62 * scale, minutes: 43200, resetIn: 500 * 3600)),
        ]
    }

    static let still = [claude(session: 94, weekly: 37), codex(session: 8, weekly: 26)]
}
