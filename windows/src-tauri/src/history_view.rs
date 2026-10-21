//! What the history graphs receive for one provider: readings and computed figures only.

use serde::Serialize;

use crate::history::{period, UsageHistory};
use crate::model::UsageWindow;

/// Columns of the histogram, rays of the burst.
const HISTOGRAM_SLICES: usize = 24;
const BURST_SLICES: usize = 36;
/// Bars of the spark strip, which depend on the style's bar pitch over the 472 pt cell:
/// iris 6 pt, dot 7.2 pt, mono 4 pt. The strip spaces whatever arrives evenly.
const SPARK_SLICES_IRIS: usize = 78;
const SPARK_SLICES_DOT: usize = 65;
const SPARK_SLICES_MONO: usize = 118;
const MILLIS: i64 = 1000;
/// Fewer samples than this in the period and the graphs say they are still recording.
const SAMPLES_TO_DRAW: usize = 2;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PointView {
    /// Epoch milliseconds.
    pub at: i64,
    pub remaining: f64,
}

/// Remaining % per slice for each style's strip.
#[derive(Debug, Clone, Serialize)]
pub struct SparkSlices {
    pub iris: Vec<Option<f64>>,
    pub dot: Vec<Option<f64>>,
    pub mono: Vec<Option<f64>>,
}

/// The history of a provider's short window (its long window when that is the only one), within
/// the window's current period. Times are epoch milliseconds.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct HistoryView {
    pub now: i64,
    pub period_start: Option<i64>,
    pub period_end: Option<i64>,
    pub points: Vec<PointView>,
    /// Too little recorded in the period to draw a chart.
    pub is_recording: bool,
    /// % per hour over the last 60 min; `None` without enough data or use.
    pub burn_rate: Option<f64>,
    /// `None` when the allowance lasts past the reset.
    pub projected_empty: Option<i64>,
    /// % used per histogram slice; `None` after now.
    pub used_slices: Vec<Option<f64>>,
    /// % used per burst slice; `None` after now.
    pub burst_slices: Vec<Option<f64>>,
    pub remaining_slices: SparkSlices,
}

pub fn history_view(history: &UsageHistory, id: &str, window: &UsageWindow, now: i64) -> HistoryView {
    let period = period(window);
    let remaining = |slices| history.remaining_per_slice(id, window, now, slices);
    HistoryView {
        now: now * MILLIS,
        period_start: period.map(|(start, _)| start * MILLIS),
        period_end: period.map(|(_, end)| end * MILLIS),
        points: history
            .points(id, window, now)
            .into_iter()
            .map(|point| PointView { at: point.at * MILLIS, remaining: point.remaining })
            .collect(),
        is_recording: history.samples_in(id, window, now).len() < SAMPLES_TO_DRAW,
        burn_rate: history.burn_rate(id, window, now),
        projected_empty: history.projected_empty(id, window, now).map(|at| at * MILLIS),
        used_slices: history.used_per_slice(id, window, now, HISTOGRAM_SLICES),
        burst_slices: history.used_per_slice(id, window, now, BURST_SLICES),
        remaining_slices: SparkSlices {
            iris: remaining(SPARK_SLICES_IRIS),
            dot: remaining(SPARK_SLICES_DOT),
            mono: remaining(SPARK_SLICES_MONO),
        },
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::*;
    use crate::history::UsageSample;

    const NOW: i64 = 1_800_000_000;
    const SAMPLE_STEP_MINUTES: i64 = 3;
    const LONG_DRIFT: f64 = 3.0;
    /// Where `dump_preview_history` writes, for `scripts/preview.mjs`.
    const OUTPUT_VARIABLE: &str = "USAGE_GAUGE_PREVIEW_HISTORY";

    /// A sample tool: its short window as (minutes ago, remaining) keyframes, oldest first, the
    /// window itself and the long window's share now. The macOS `SampleData` renders the same.
    struct Profile {
        id: &'static str,
        keyframes: &'static [(i64, f64)],
        window: (u32, i64),
        long_now: f64,
    }

    const PROFILES: [Profile; 4] = [
        Profile { id: "claude", keyframes: &[(70, 100.0), (46, 100.0), (40, 96.0), (21, 96.0), (15, 94.0), (0, 94.0)], window: (300, 230 * 60), long_now: 37.0 },
        Profile { id: "codex", keyframes: &[(253, 100.0), (200, 66.0), (150, 52.0), (110, 52.0), (85, 30.0), (50, 22.0), (20, 19.0), (8, 9.0), (0, 8.0)], window: (300, 47 * 60), long_now: 26.0 },
        Profile { id: "gemini", keyframes: &[(900, 100.0), (780, 94.0), (700, 82.0), (560, 82.0), (500, 72.0), (200, 72.0), (0, 71.0)], window: (1440, 9 * 3600), long_now: 88.0 },
        Profile { id: "cursor", keyframes: &[(170, 100.0), (140, 90.0), (105, 68.0), (95, 64.0), (60, 60.0), (30, 52.0), (0, 46.0)], window: (300, 130 * 60), long_now: 53.0 },
    ];

    fn interpolated(keyframes: &[(i64, f64)], ago: i64) -> f64 {
        let next = keyframes.iter().position(|(frame_ago, _)| *frame_ago <= ago).unwrap_or(keyframes.len() - 1);
        if next == 0 {
            return keyframes[0].1;
        }
        let ((from_ago, from), (to_ago, to)) = (keyframes[next - 1], keyframes[next]);
        from + (to - from) * (from_ago - ago) as f64 / (from_ago - to_ago) as f64
    }

    fn sample_history() -> UsageHistory {
        let samples = PROFILES.iter().map(|profile| {
            let oldest = profile.keyframes[0].0;
            let series = (0..=oldest / SAMPLE_STEP_MINUTES)
                .map(|step| oldest - step * SAMPLE_STEP_MINUTES)
                .map(|ago| UsageSample {
                    at: NOW - ago * 60,
                    session: Some(interpolated(profile.keyframes, ago).round()),
                    long: Some((profile.long_now + LONG_DRIFT * ago as f64 / oldest as f64).round()),
                    session_minutes: None,
                    long_minutes: None,
                })
                .collect();
            (profile.id.to_owned(), series)
        });
        UsageHistory::from_samples(samples.collect::<BTreeMap<_, _>>())
    }

    #[test]
    fn history_view_reports_the_short_window_in_milliseconds() {
        let history = sample_history();
        let claude = &PROFILES[0];
        let window = UsageWindow { used_percent: 6.0, resets_at: Some(NOW + claude.window.1), window_minutes: Some(claude.window.0) };
        let view = history_view(&history, "claude", &window, NOW);
        assert_eq!(view.now, NOW * MILLIS);
        assert_eq!(view.period_end, Some((NOW + claude.window.1) * MILLIS));
        assert!(!view.is_recording);
        assert_eq!((view.used_slices.len(), view.burst_slices.len()), (HISTOGRAM_SLICES, BURST_SLICES));
        assert_eq!(view.remaining_slices.mono.len(), SPARK_SLICES_MONO);
        assert!(view.points.iter().all(|point| point.at <= NOW * MILLIS) && view.points.len() > 2);
    }

    /// Writes the sample providers' history views as JSON, so the preview renders what the app
    /// would send. Run by `npm run preview`.
    #[test]
    #[ignore = "writes the preview fixture; run by `npm run preview`"]
    fn dump_preview_history() {
        let Ok(path) = std::env::var(OUTPUT_VARIABLE) else { return };
        let history = sample_history();
        let views: BTreeMap<&str, HistoryView> = PROFILES
            .iter()
            .map(|profile| {
                let (minutes, resets_in) = profile.window;
                let remaining = profile.keyframes.last().map_or(100.0, |(_, share)| *share);
                let window = UsageWindow { used_percent: 100.0 - remaining, resets_at: Some(NOW + resets_in), window_minutes: Some(minutes) };
                (profile.id, history_view(&history, profile.id, &window, NOW))
            })
            .collect();
        std::fs::write(path, serde_json::to_string(&views).unwrap()).unwrap();
    }
}
