import Foundation

/// Display names and ordering for providers CodexBar reports. Unknown ids still render,
/// titled from the id, so newly supported providers show up without a release.
public enum ProviderCatalog {
    public static let pinnedOrder = ["claude", "codex"]

    private static let titles = [
        "claude": "Claude", "codex": "Codex", "gemini": "Gemini", "antigravity": "Antigravity",
        "cursor": "Cursor", "copilot": "Copilot", "openrouter": "OpenRouter", "windsurf": "Windsurf",
        "zai": "z.ai", "kiro": "Kiro", "grok": "Grok", "openai": "OpenAI", "opencode": "OpenCode",
    ]

    public static func title(for id: String) -> String {
        titles[id] ?? id.prefix(1).uppercased() + id.dropFirst()
    }

    /// A provider that failed this time keeps its last good reading, so one dropped request does
    /// not blank the gauge. Its older `measuredAt` still shows how old the numbers are.
    public static func merge(latest: [ProviderUsage], previous: [ProviderUsage]) -> [ProviderUsage] {
        latest.map { usage in
            guard !usage.isAvailable, let kept = previous.first(where: { $0.id == usage.id && $0.isAvailable }) else {
                return usage
            }
            return kept
        }
    }

    /// Pinned providers first, then everything else in the order CodexBar listed it.
    public static func sorted(_ usage: [ProviderUsage]) -> [ProviderUsage] {
        let pinned = pinnedOrder.compactMap { id in usage.first { $0.id == id } }
        return pinned + usage.filter { !pinnedOrder.contains($0.id) }
    }
}

/// One rate-limit window, such as the 5-hour session or the weekly allowance.
public struct UsageWindow: Equatable, Sendable {
    public let usedPercent: Double
    public let resetsAt: Date?
    public let windowMinutes: Int?

    public init(usedPercent: Double, resetsAt: Date?, windowMinutes: Int? = nil) {
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
        self.windowMinutes = windowMinutes
    }

    public var remainingPercent: Double {
        min(100, max(0, 100 - usedPercent))
    }

    /// Whole percent for display. Rounds to nearest, but never shows 0 while something is left
    /// or 100 while something is used, so the figure cannot claim a state the window is not in.
    public var displayPercent: Int {
        let remaining = remainingPercent
        if remaining > 0 && remaining < 1 { return 1 }
        if remaining > 99 && remaining < 100 { return 99 }
        return Int(remaining.rounded())
    }

    /// The window as it stands at `now`: once its reset time has passed the allowance is full
    /// again, even before CodexBar is asked for fresh numbers.
    public func resolved(at now: Date) -> UsageWindow {
        guard let resetsAt, resetsAt <= now else { return self }
        return UsageWindow(usedPercent: 0, resetsAt: nil, windowMinutes: windowMinutes)
    }

    /// "5시간", "주간", … derived from the window length; nil when CodexBar did not say.
    public var label: String? {
        guard let windowMinutes else { return nil }
        switch windowMinutes {
        case 10080: return "주간"
        case 43200, 44640: return "월간"
        case 1440: return "일간"
        case ..<1440 where windowMinutes % 60 == 0: return "\(windowMinutes / 60)시간"
        default: return nil
        }
    }

    /// 0...1, how much of the window has passed at `now`; nil when the reset time or length is unknown.
    public func elapsedFraction(now: Date) -> Double? {
        guard let resetsAt, let windowMinutes, windowMinutes > 0 else { return nil }
        let left = resetsAt.timeIntervalSince(now) / (Double(windowMinutes) * 60)
        return min(1, max(0, 1 - left))
    }
}

public struct ProviderUsage: Equatable, Sendable, Identifiable {
    public let id: String
    public let plan: String?
    public let session: UsageWindow?
    public let weekly: UsageWindow?
    public let errorMessage: String?
    /// When CodexBar measured these numbers; it may serve cached data older than the fetch.
    public let measuredAt: Date?

    public init(id: String, plan: String? = nil, session: UsageWindow?, weekly: UsageWindow?,
                errorMessage: String? = nil, measuredAt: Date? = nil) {
        self.id = id
        self.plan = plan
        self.session = session
        self.weekly = weekly
        self.errorMessage = errorMessage
        self.measuredAt = measuredAt
    }

    /// Both windows as they stand at `now` (see `UsageWindow.resolved(at:)`).
    public func resolved(at now: Date) -> ProviderUsage {
        ProviderUsage(id: id, plan: plan, session: session?.resolved(at: now), weekly: weekly?.resolved(at: now),
                      errorMessage: errorMessage, measuredAt: measuredAt)
    }

    /// The soonest reset still ahead of `now`, so the app can refresh right after it.
    public func nextReset(after now: Date) -> Date? {
        [session?.resetsAt, weekly?.resetsAt].compactMap { $0 }.filter { $0 > now }.min()
    }

    public var title: String { ProviderCatalog.title(for: id) }
    public var isAvailable: Bool { session != nil || weekly != nil }
}
