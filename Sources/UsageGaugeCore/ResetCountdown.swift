import Foundation

/// Formats the time left until a window resets, e.g. "3시간 50분" or "2일 4시간".
public enum ResetCountdown {
    public static let unknown = "–"
    public static let imminent = "곧"

    private static let minutesPerHour = 60
    private static let minutesPerDay = 24 * 60

    public static func text(until date: Date?, now: Date = Date()) -> String {
        guard let date else { return unknown }
        let minutes = Int(date.timeIntervalSince(now) / 60)
        if minutes < 1 { return imminent }
        if minutes >= minutesPerDay {
            return "\(minutes / minutesPerDay)일 \(minutes % minutesPerDay / minutesPerHour)시간"
        }
        if minutes >= minutesPerHour {
            return "\(minutes / minutesPerHour)시간 \(minutes % minutesPerHour)분"
        }
        return "\(minutes)분"
    }

    /// Terse form for the monospaced styles, e.g. "3h 50m", "2d 4h", "47m", "<1m".
    public static func compact(until date: Date?, now: Date = Date()) -> String {
        guard let date else { return unknown }
        let minutes = Int(date.timeIntervalSince(now) / 60)
        if minutes < 1 { return "<1m" }
        if minutes >= minutesPerDay {
            return "\(minutes / minutesPerDay)d \(minutes % minutesPerDay / minutesPerHour)h"
        }
        if minutes >= minutesPerHour {
            return "\(minutes / minutesPerHour)h \(minutes % minutesPerHour)m"
        }
        return "\(minutes)m"
    }
}
