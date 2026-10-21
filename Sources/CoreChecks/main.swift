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

// A failed provider keeps its last good reading
let good = ProviderUsage(id: "codex", session: ahead, weekly: nil)
let failed = ProviderUsage(id: "codex", session: nil, weekly: nil, errorMessage: "timeout")
expect(ProviderCatalog.merge(latest: [failed], previous: [good]) == [good], "a dropped request keeps the last good numbers")
expect(ProviderCatalog.merge(latest: [failed], previous: []) == [failed], "with nothing to keep, the error shows")

// Colours for providers without a signature colour
expect(ProviderCatalog.hue(for: "windsurf") == ProviderCatalog.hue(for: "windsurf"), "a provider keeps its hue")
expect(ProviderCatalog.hue(for: "windsurf") != ProviderCatalog.hue(for: "openrouter"), "different providers get different hues")
expect((0..<1).contains(ProviderCatalog.hue(for: "grok")), "hues stay within 0..<1")

// Glass tint follows the backdrop
expect(BackdropTone.tintOpacity(luminance: 1) > BackdropTone.tintOpacity(luminance: 0), "glass is darker over a bright backdrop")
expect(BackdropTone.tintOpacity(luminance: 5) == BackdropTone.tintRange.upperBound, "brightness above 1 clamps to the darkest tint")
expect(abs((BackdropTone.averageLuminance(of: solidImage(gray: 255)) ?? 0) - 1) < 0.01, "a white image measures as bright")
expect((BackdropTone.averageLuminance(of: solidImage(gray: 0)) ?? 1) < 0.01, "a black image measures as dark")

// Wallpaper behind the panel
let screen = CGRect(x: 0, y: 0, width: 1000, height: 500)
expect(BackdropTone.wallpaperRegion(behind: CGRect(x: 0, y: 250, width: 500, height: 250), on: screen,
                                    imageSize: CGSize(width: 2000, height: 1000)) == CGRect(x: 0, y: 0, width: 1000, height: 500),
       "a panel in the top-left quarter reads the wallpaper's top-left quarter")
expect(BackdropTone.wallpaperRegion(behind: CGRect(x: 0, y: 0, width: 1000, height: 500), on: screen,
                                    imageSize: CGSize(width: 1000, height: 1000)) == CGRect(x: 0, y: 250, width: 1000, height: 500),
       "a taller wallpaper is cropped top and bottom, as macOS fills the screen")

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
expect(ResetCountdown.compact(until: now.addingTimeInterval(230 * 60), now: now) == "3h 50m", "compact hours and minutes")
expect(ResetCountdown.compact(until: now.addingTimeInterval(76 * 3600), now: now) == "3d 4h", "compact days and hours")
expect(ResetCountdown.compact(until: now.addingTimeInterval(30), now: now) == "<1m", "compact under a minute")

// Usage history
let historyWindow = UsageWindow(usedPercent: 0, resetsAt: now.addingTimeInterval(3 * 3600), windowMinutes: 300)
func historyUsage(remaining: Double, long: Double? = nil, resetsIn: TimeInterval = 3 * 3600) -> ProviderUsage {
    ProviderUsage(id: "claude",
                  session: UsageWindow(usedPercent: 100 - remaining, resetsAt: now.addingTimeInterval(resetsIn), windowMinutes: 300),
                  weekly: long.map { UsageWindow(usedPercent: 100 - $0, resetsAt: nil, windowMinutes: 10080) })
}
/// A history of the 300-minute window with a sample every `step` seconds, the last one at `end`.
func drained(_ remaining: [Double], step: TimeInterval, endingAt end: Date = now) -> UsageHistory {
    var history = UsageHistory()
    for (offset, value) in remaining.enumerated() {
        let at = end.addingTimeInterval(-step * Double(remaining.count - 1 - offset))
        history.record([historyUsage(remaining: value)], at: at)
    }
    return history
}

var recorded = UsageHistory()
recorded.record([historyUsage(remaining: 80, long: 60), ProviderUsage(id: "gemini", session: nil, weekly: nil)], at: now)
expect(recorded.samples.keys.sorted() == ["claude"], "only available providers are recorded")
recorded.record([historyUsage(remaining: 79)], at: now.addingTimeInterval(49))
expect(recorded.samples["claude"]?.count == 1, "a second sample under 50 s later is skipped")
recorded.record([historyUsage(remaining: 79)], at: now.addingTimeInterval(50))
expect(recorded.samples["claude"]?.count == 2, "a sample 50 s later is kept")
recorded.record([historyUsage(remaining: 70)], at: now.addingTimeInterval(27 * 3600))
expect(recorded.samples["claude"]?.count == 1, "samples older than 26 h are pruned")
var crowded = UsageHistory()
for second in 0..<1100 { crowded.record([historyUsage(remaining: 50)], at: now.addingTimeInterval(Double(second) * 60)) }
expect(crowded.samples["claude"]?.count == 1000, "a series is capped at 1 000 samples")
expect(crowded.samples["claude"]?.last?.at == now.addingTimeInterval(1099 * 60), "the cap keeps the newest samples")

let drainHistory = drained([90, 85, 80, 75, 70, 65, 60, 55, 50, 45, 40, 35, 30], step: 300)   // 5 %/5 min = 60 %/h
let hourWindow = historyUsage(remaining: 30).session!
expect(drainHistory.samples(for: "claude", in: hourWindow, now: now).count == 13, "samples inside the period are returned")
expect(drainHistory.samples(for: "claude", in: UsageWindow(usedPercent: 0, resetsAt: nil, windowMinutes: 300), now: now).isEmpty,
       "a window without a reset time has no samples")
expect(drainHistory.burnRate(for: "claude", window: hourWindow, now: now).map { abs($0 - 60) < 0.001 } == true, "burn rate is the % used per hour")
let emptyIn = drainHistory.projectedEmpty(for: "claude", window: hourWindow, now: now)
expect(emptyIn == now.addingTimeInterval(1800), "30 % left at 60 %/h runs out in 30 min")
let lasting = drained([100, 99, 98, 97, 96, 95], step: 300)
expect(lasting.burnRate(for: "claude", window: historyUsage(remaining: 95).session!, now: now).map { abs($0 - 12) < 0.001 } == true, "slow burn rate")
expect(lasting.projectedEmpty(for: "claude", window: historyUsage(remaining: 95).session!, now: now) == nil, "a window that lasts past its reset has no empty time")
expect(drained([90, 85], step: 300).burnRate(for: "claude", window: hourWindow, now: now) == nil, "under 10 min of data has no burn rate")
expect(drained([50, 50, 50, 50], step: 300).burnRate(for: "claude", window: hourWindow, now: now) == nil, "nothing used has no burn rate")
expect(drained([30, 40, 50, 60], step: 300).burnRate(for: "claude", window: hourWindow, now: now) == nil, "rises are not usage")

// A reset starts a fresh series: the same history read against the next period shows only new samples.
var resetHistory = drained([20, 10, 5], step: 60, endingAt: now.addingTimeInterval(-600))
resetHistory.record([historyUsage(remaining: 100, resetsIn: 300 * 60)], at: now)
let nextPeriod = historyUsage(remaining: 100, resetsIn: 300 * 60).session!
expect(resetHistory.samples(for: "claude", in: nextPeriod, now: now).count == 1, "after a reset only the new period's samples count")

// Slices
let sliced = drained([100, 90, 80, 85, 60], step: 1200, endingAt: now.addingTimeInterval(-300))
let slicedWindow = UsageWindow(usedPercent: 40, resetsAt: now.addingTimeInterval(3.5 * 3600), windowMinutes: 300)   // started 90 min ago
let used = sliced.usedPerSlice(for: "claude", window: slicedWindow, now: now, slices: 5)
expect(used.count == 5 && used[0] == 20 && used[1] == 25 && used[2] == nil && used[4] == nil,
       "used per slice sums drops, ignores rises, nil after now")
expect(drained([100, 90, 90, 90], step: 1200, endingAt: now.addingTimeInterval(-300))
        .usedPerSlice(for: "claude", window: slicedWindow, now: now, slices: 5)[1] == 0, "a past slice without drops is 0")
let remainingSlices = sliced.remainingPerSlice(for: "claude", window: slicedWindow, now: now, slices: 5)
expect(remainingSlices[0] == 80 && remainingSlices[1] == 60 && remainingSlices[2] == nil,
       "remaining per slice is the last sample in it, nil after now")
let carried = drained([100, 90, 80], step: 1200, endingAt: now.addingTimeInterval(-3000))
    .remainingPerSlice(for: "claude", window: slicedWindow, now: now, slices: 5)
expect(carried[0] == 80 && carried[1] == 80, "remaining per slice carries the last value into a slice without samples")
let lateStart = drained([80, 70], step: 600).remainingPerSlice(for: "claude", window: slicedWindow, now: now, slices: 5)
expect(lateStart[0] == nil && lateStart[1] == 70, "remaining per slice is nil before the first sample")
expect(drained([50], step: 60).usedPerSlice(for: "claude", window: slicedWindow, now: now, slices: 0).isEmpty, "zero slices is empty")

// Codable and bad input
let stored = UsageHistory(samples: ["claude": [
    UsageSample(at: Date().addingTimeInterval(-600), session: 80, long: 60),
    UsageSample(at: Date().addingTimeInterval(-300), session: 70, long: nil),
]])
expect((try? JSONDecoder().decode(UsageHistory.self, from: JSONEncoder().encode(stored))) == stored, "history survives a JSON round trip")
let dirty = UsageHistory(samples: ["claude": [
    UsageSample(at: now, session: 50, long: nil),
    UsageSample(at: now, session: 40, long: nil),
    UsageSample(at: now.addingTimeInterval(-60), session: .nan, long: nil),
    UsageSample(at: now.addingTimeInterval(-120), session: 140, long: nil),
    UsageSample(at: now.addingTimeInterval(-180), session: nil, long: nil),
    UsageSample(at: now.addingTimeInterval(-240), session: 30, long: nil),
]])
expect(dirty.samples["claude"]?.map(\.session) == [30, 40], "invalid samples are dropped, duplicates keep the last, oldest first")
let future = Date().addingTimeInterval(7200).timeIntervalSinceReferenceDate
let pastSeconds = Date().addingTimeInterval(-60).timeIntervalSinceReferenceDate
let mixed = Data("""
{"samples": {"claude": [{"at": \(pastSeconds), "session": 10}, {"at": \(future), "session": 20}, {"at": 5, "session": 500}, {"nope": true}]}}
""".utf8)
expect((try? JSONDecoder().decode(UsageHistory.self, from: mixed))?.samples["claude"]?.map(\.session) == [10],
       "decoding drops future, out-of-range and malformed samples")
expect((try? JSONDecoder().decode(UsageHistory.self, from: Data("not json".utf8))) == nil, "corrupt history throws instead of crashing")
expect((try? JSONDecoder().decode(UsageHistory.self, from: Data("{\"samples\": 3}".utf8))) == nil, "wrongly shaped history throws")

print(failures.isEmpty ? "\nall checks passed" : "\n\(failures.count) check(s) failed")
exit(failures.isEmpty ? 0 : 1)
