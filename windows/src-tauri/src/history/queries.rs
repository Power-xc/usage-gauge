//! What the graphs ask of a history: points, burn rate, projected empty and per-slice values.

use super::{UsageHistory, UsageSample};
use crate::model::UsageWindow;

/// The last this many seconds of a window's period make up its burn rate.
const BURN_LOOKBACK_SECONDS: i64 = 3600;
/// Under this much data there is no burn rate.
const MINIMUM_BURN_SPAN_SECONDS: i64 = 600;
const SECONDS_PER_HOUR: f64 = 3600.0;
/// For samples without window lengths: windows longer than this are taken for the long one.
const LONG_WINDOW_MINUTES: u32 = 1440;

/// One reading of a window's remaining share.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct UsagePoint {
    pub at: i64,
    pub remaining: f64,
}

#[derive(Debug, Clone, Copy)]
enum Series {
    Session,
    Long,
}

impl Series {
    fn of(self, sample: &UsageSample) -> Option<f64> {
        match self {
            Self::Session => sample.session,
            Self::Long => sample.long,
        }
    }
}

impl UsageHistory {
    /// Samples of `id` inside `window`'s current period (from reset − length to now), oldest
    /// first. Empty when the window has no reset time or length.
    pub fn samples_in(&self, id: &str, window: &UsageWindow, now: i64) -> Vec<UsageSample> {
        let Some((start, _)) = period(window) else { return Vec::new() };
        let series = self.samples.get(id).map_or(&[][..], Vec::as_slice);
        series.iter().filter(|sample| sample.at >= start && sample.at <= now).cloned().collect()
    }

    /// The readings of `window` within its current period, oldest first.
    pub fn points(&self, id: &str, window: &UsageWindow, now: i64) -> Vec<UsagePoint> {
        let in_period = self.samples_in(id, window, now);
        for series in series_of(window, &in_period) {
            let points: Vec<UsagePoint> = in_period
                .iter()
                .filter_map(|sample| series.of(sample).map(|remaining| UsagePoint { at: sample.at, remaining }))
                .collect();
            if !points.is_empty() {
                return points;
            }
        }
        Vec::new()
    }

    /// % of `window` used per hour over the last 60 min of its current period; `None` with under
    /// 10 min of data or nothing used.
    pub fn burn_rate(&self, id: &str, window: &UsageWindow, now: i64) -> Option<f64> {
        let recent: Vec<UsagePoint> =
            self.points(id, window, now).into_iter().filter(|point| point.at >= now - BURN_LOOKBACK_SECONDS).collect();
        let (first, last) = (recent.first()?, recent.last()?);
        let span = last.at - first.at;
        let used = drops(&recent);
        (span >= MINIMUM_BURN_SPAN_SECONDS && used > 0.0).then(|| used / (span as f64 / SECONDS_PER_HOUR))
    }

    /// When `window` runs out at its burn rate; `None` when there is no rate or it lasts past the reset.
    pub fn projected_empty(&self, id: &str, window: &UsageWindow, now: i64) -> Option<i64> {
        let rate = self.burn_rate(id, window, now)?;
        let resets_at = window.resets_at?;
        let empty = now + (window.remaining_percent() / rate * SECONDS_PER_HOUR).round() as i64;
        (empty < resets_at).then_some(empty)
    }

    /// `slices` equal slices of the window's period from start to reset: % used in each (sum of
    /// drops between consecutive samples, rises ignored); 0 for a past slice without drops;
    /// `None` for slices after now.
    pub fn used_per_slice(&self, id: &str, window: &UsageWindow, now: i64, slices: usize) -> Vec<Option<f64>> {
        let Some(grid) = SliceGrid::new(window, now, slices) else { return Vec::new() };
        let mut used = vec![0.0; slices];
        for pair in self.points(id, window, now).windows(2) {
            used[grid.index_of(pair[1].at)] += (pair[0].remaining - pair[1].remaining).max(0.0);
        }
        (0..slices).map(|slice| grid.has_started(slice).then_some(used[slice])).collect()
    }

    /// Same slicing: remaining % at the end of each slice (last sample in it, carried forward
    /// from the previous slice when it has none); `None` before the first sample and after now.
    pub fn remaining_per_slice(&self, id: &str, window: &UsageWindow, now: i64, slices: usize) -> Vec<Option<f64>> {
        let Some(grid) = SliceGrid::new(window, now, slices) else { return Vec::new() };
        let mut last_in: Vec<Option<f64>> = vec![None; slices];
        for point in self.points(id, window, now) {
            last_in[grid.index_of(point.at)] = Some(point.remaining);
        }
        let mut carried = None;
        (0..slices)
            .map(|slice| {
                carried = last_in[slice].or(carried);
                grid.has_started(slice).then_some(carried).flatten()
            })
            .collect()
    }
}

/// Which series holds `window`: the one recorded with the same length. Older samples carry no
/// lengths; then a window longer than a day is taken for the long one. The other series is the
/// fallback, for a provider that reports a single window in either slot.
fn series_of(window: &UsageWindow, samples: &[UsageSample]) -> [Series; 2] {
    if let Some(minutes) = window.window_minutes {
        if samples.iter().any(|sample| sample.session_minutes == Some(minutes)) {
            return [Series::Session, Series::Long];
        }
        if samples.iter().any(|sample| sample.long_minutes == Some(minutes)) {
            return [Series::Long, Series::Session];
        }
    }
    if window.window_minutes.unwrap_or(0) > LONG_WINDOW_MINUTES {
        [Series::Long, Series::Session]
    } else {
        [Series::Session, Series::Long]
    }
}

/// Start and reset of the window's current period.
pub fn period(window: &UsageWindow) -> Option<(i64, i64)> {
    let (resets_at, minutes) = (window.resets_at?, window.window_minutes?);
    (minutes > 0).then(|| (resets_at - i64::from(minutes) * 60, resets_at))
}

fn drops(points: &[UsagePoint]) -> f64 {
    points.windows(2).map(|pair| (pair[0].remaining - pair[1].remaining).max(0.0)).sum()
}

/// A window's period cut into equal slices.
struct SliceGrid {
    start: i64,
    length: f64,
    count: usize,
    now: i64,
}

impl SliceGrid {
    fn new(window: &UsageWindow, now: i64, slices: usize) -> Option<Self> {
        let (start, end) = period(window)?;
        (slices > 0).then(|| Self { start, length: (end - start) as f64 / slices as f64, count: slices, now })
    }

    fn index_of(&self, at: i64) -> usize {
        let slice = ((at - self.start) as f64 / self.length) as i64;
        slice.clamp(0, self.count as i64 - 1) as usize
    }

    fn has_started(&self, slice: usize) -> bool {
        self.start as f64 + slice as f64 * self.length <= self.now as f64
    }
}
