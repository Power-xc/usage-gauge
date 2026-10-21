import Foundation
import UsageGaugeCore

/// Clock-time wording of a tool's reset and measuring times, shared by the hover line and the
/// detail page.
enum HoverDetail {
    private static let resetFormatter = formatter("a h:mm")
    private static let measuredFormatter = formatter("h:mm")

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = format
        return formatter
    }

    /// "오후 4:00"
    static func clock(_ date: Date) -> String { resetFormatter.string(from: date) }

    /// "초기화 오후 4:00 · 측정 12:04"; whichever part is unknown is left out.
    static func line(for usage: ProviderUsage) -> String {
        var parts: [String] = []
        if let reset = usage.session?.resetsAt ?? usage.weekly?.resetsAt { parts.append("초기화 \(clock(reset))") }
        if let measured = usage.measuredAt { parts.append("측정 \(measuredFormatter.string(from: measured))") }
        return parts.isEmpty ? "연결 안 됨" : parts.joined(separator: " · ")
    }

    /// "오후 12:04 기준" wording of when the numbers were measured, or nil when unknown.
    static func measured(_ usage: ProviderUsage) -> String? {
        usage.measuredAt.map { "측정 \(clock($0))" }
    }
}
