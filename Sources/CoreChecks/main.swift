import CoreGraphics
import Foundation
import UsageGaugeCore

// Plain assertion runner: `swift run CoreChecks` exits non-zero when any check fails.

var failures: [String] = []

func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
        print("PASS  \(name)")
    } else {
        print("FAIL  \(name)")
        failures.append(name)
    }
}

/// A small single-colour greyscale image, for measuring brightness.
func solidImage(gray: UInt8) -> CGImage {
    let side = 4
    let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    context.setFillColor(gray: CGFloat(gray) / 255, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    return context.makeImage()!
}

let fixture = Data("""
[
  {"provider": "gemini", "error": {"kind": "provider", "message": "Sign in again", "code": 3}},
  {"provider": "codex", "source": "oauth", "unknownField": {"nested": true},
   "usage": {"loginMethod": "plus", "updatedAt": "2026-10-21T04:51:10Z",
             "primary": {"usedPercent": 89, "windowMinutes": 300, "resetsAt": "2026-10-21T06:08:03Z"},
             "secondary": {"usedPercent": 14, "windowMinutes": 10080, "resetsAt": "2026-10-28T01:08:03.250Z"}}},
  {"provider": "cursor", "usage": {"primary": {"usedPercent": 40, "windowMinutes": 43200}}},
  {"provider": "claude",
   "usage": {"loginMethod": "max",
             "primary": {"usedPercent": 6, "windowMinutes": 300, "resetsAt": "2026-10-21T06:50:00Z"},
             "secondary": {"usedPercent": 63}}}
]
""".utf8)

// Decoding
do {
    let usage = try CodexBarDecoder.decode(fixture)
    expect(usage.map(\.id) == ["claude", "codex", "gemini", "cursor"], "pinned providers first, others in payload order")
    expect(usage[0].plan == "Max", "plan is capitalised")
    expect(usage[0].session?.remainingPercent == 94, "remaining = 100 - used")
    expect(usage[0].weekly?.resetsAt == nil, "missing resetsAt decodes as nil")
    expect(usage[1].weekly?.resetsAt != nil, "fractional-second ISO 8601 dates decode")
    expect(usage[2].isAvailable == false && usage[2].errorMessage == "Sign in again", "provider errors are kept per provider")
    expect(usage[3].title == "Cursor" && usage[3].weekly == nil, "single-window providers decode")
    expect(usage[1].measuredAt != nil && usage[0].measuredAt == nil, "measurement time is kept when CodexBar sends it")
} catch {
    expect(false, "fixture decodes (\(error))")
}
expect((try? CodexBarDecoder.decode(Data("not json".utf8))) == nil, "invalid output throws")
expect(ProviderCatalog.title(for: "someNewTool") == "SomeNewTool", "unknown providers get a readable title")

// Elapsed share of a window
let start = Date(timeIntervalSince1970: 0)
expect(UsageWindow(usedPercent: 0, resetsAt: start.addingTimeInterval(3600), windowMinutes: 300).elapsedFraction(now: start) == 0.8,
       "one hour left of five means 80% has passed")
expect(UsageWindow(usedPercent: 0, resetsAt: start.addingTimeInterval(-60), windowMinutes: 300).elapsedFraction(now: start) == 1,
       "a reset time in the past clamps to fully elapsed")
expect(UsageWindow(usedPercent: 0, resetsAt: nil, windowMinutes: 300).elapsedFraction(now: start) == nil,
       "no reset time means no elapsed share")

// Displayed percent
expect(UsageWindow(usedPercent: 5.4, resetsAt: nil).displayPercent == 95, "94.6% left rounds to 95")
expect(UsageWindow(usedPercent: 99.6, resetsAt: nil).displayPercent == 1, "a sliver left never shows as 0")
expect(UsageWindow(usedPercent: 0.3, resetsAt: nil).displayPercent == 99, "a sliver used never shows as 100")
expect(UsageWindow(usedPercent: 100, resetsAt: nil).displayPercent == 0, "nothing left shows 0")

// Windows after their reset
let past = UsageWindow(usedPercent: 90, resetsAt: start.addingTimeInterval(-1), windowMinutes: 300)
let ahead = UsageWindow(usedPercent: 90, resetsAt: start.addingTimeInterval(60), windowMinutes: 300)
expect(past.resolved(at: start).remainingPercent == 100, "a window whose reset has passed reads as full")
expect(ahead.resolved(at: start) == ahead, "a window before its reset is unchanged")
expect(ProviderUsage(id: "claude", session: past, weekly: ahead).nextReset(after: start) == ahead.resetsAt,
       "the next reset is the soonest one still ahead")

// Glass tint follows the backdrop
expect(BackdropTone.tintOpacity(luminance: 1) > BackdropTone.tintOpacity(luminance: 0), "glass is darker over a bright backdrop")
expect(BackdropTone.tintOpacity(luminance: 5) == BackdropTone.tintRange.upperBound, "brightness above 1 clamps to the darkest tint")
expect(abs((BackdropTone.averageLuminance(of: solidImage(gray: 255)) ?? 0) - 1) < 0.01, "a white image measures as bright")
expect((BackdropTone.averageLuminance(of: solidImage(gray: 0)) ?? 1) < 0.01, "a black image measures as dark")

// Window labels
expect(UsageWindow(usedPercent: 0, resetsAt: nil, windowMinutes: 300).label == "5시간", "300 minutes reads as 5시간")
expect(UsageWindow(usedPercent: 0, resetsAt: nil, windowMinutes: 10080).label == "주간", "a week reads as 주간")
expect(UsageWindow(usedPercent: 0, resetsAt: nil, windowMinutes: 43200).label == "월간", "30 days reads as 월간")
expect(UsageWindow(usedPercent: 0, resetsAt: nil).label == nil, "unknown length has no label")

// Remaining percent is clamped to 0...100
expect(UsageWindow(usedPercent: 120, resetsAt: nil).remainingPercent == 0, "over-used clamps to 0")
expect(UsageWindow(usedPercent: -5, resetsAt: nil).remainingPercent == 100, "negative usage clamps to 100")

// Level thresholds
expect(UsageLevel(remainingPercent: 30.5) == .comfortable, "above 30% is comfortable")
expect(UsageLevel(remainingPercent: 30) == .low, "30% is low")
expect(UsageLevel(remainingPercent: 10) == .critical, "10% is critical")
expect(UsageLevel(remainingPercent: 0) == .critical, "0% is critical")

// Countdown text
let now = Date(timeIntervalSince1970: 1_800_000_000)
expect(ResetCountdown.text(until: nil, now: now) == "–", "unknown reset")
expect(ResetCountdown.text(until: now.addingTimeInterval(30), now: now) == "곧", "under a minute")
expect(ResetCountdown.text(until: now.addingTimeInterval(-600), now: now) == "곧", "already passed")
expect(ResetCountdown.text(until: now.addingTimeInterval(59 * 60), now: now) == "59분", "minutes only")
expect(ResetCountdown.text(until: now.addingTimeInterval(230 * 60), now: now) == "3시간 50분", "hours and minutes")
expect(ResetCountdown.text(until: now.addingTimeInterval(76 * 3600), now: now) == "3일 4시간", "days and hours")

print(failures.isEmpty ? "\nall checks passed" : "\n\(failures.count) check(s) failed")
exit(failures.isEmpty ? 0 : 1)
