//! A short record of how each provider's windows drained, kept for the history graphs. Mirrors
//! the macOS app's `UsageHistory`. Holds only provider ids, timestamps and percentages. Times are
//! Unix seconds.

mod file;
mod queries;
#[cfg(test)]
mod tests;

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

use crate::model::ProviderUsage;

pub use queries::period;

/// Samples older than this are dropped.
const RETENTION_SECONDS: i64 = 26 * 3600;
/// Most samples kept per provider.
const CAPACITY: usize = 1000;
/// A provider is not sampled again within this many seconds of its last sample.
const MINIMUM_SPACING_SECONDS: i64 = 50;
const PERCENT_RANGE: std::ops::RangeInclusive<f64> = 0.0..=100.0;

/// The remaining share of a provider's windows at one moment.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UsageSample {
    pub at: i64,
    /// Remaining % of the provider's short window at `at`.
    pub session: Option<f64>,
    /// Remaining % of the provider's long window at `at`.
    pub long: Option<f64>,
    /// Lengths of the two windows when recorded, so a query can tell which series belongs to the
    /// window it asks about.
    pub session_minutes: Option<u32>,
    pub long_minutes: Option<u32>,
}

impl UsageSample {
    /// In range and carrying at least one reading.
    fn is_valid(&self) -> bool {
        let mut readings = [self.session, self.long].into_iter().flatten().peekable();
        readings.peek().is_some() && readings.all(|share| share.is_finite() && PERCENT_RANGE.contains(&share))
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize)]
pub struct UsageHistory {
    samples: BTreeMap<String, Vec<UsageSample>>,
}

impl UsageHistory {
    /// Sorts, dedupes and caps each series and drops invalid samples. It has no clock, so unlike
    /// loading it keeps samples of any date.
    pub fn from_samples(samples: BTreeMap<String, Vec<UsageSample>>) -> Self {
        Self { samples: sanitized_all(samples) }
    }

    #[cfg(test)]
    pub fn samples(&self) -> &BTreeMap<String, Vec<UsageSample>> {
        &self.samples
    }

    /// Appends one sample per available provider (skipping one whose last sample is under 50 s
    /// old) and keeps 26 hours, at most 1 000 per provider. A sample is dated when the provider
    /// was measured, and read as of then, so a window whose reset had already passed counts as
    /// full instead of carrying its old share into the new period.
    pub fn record(&mut self, providers: &[ProviderUsage], now: i64) {
        for usage in providers.iter().filter(|usage| usage.is_available()) {
            let measured = usage.measured_at.unwrap_or(now).min(now);
            let series = self.samples.entry(usage.id.to_owned()).or_default();
            if series.last().is_some_and(|last| measured - last.at < MINIMUM_SPACING_SECONDS) {
                continue;
            }
            let reading = usage.resolved(measured);
            series.push(UsageSample {
                at: measured,
                session: reading.session.as_ref().map(|window| window.remaining_percent()),
                long: reading.weekly.as_ref().map(|window| window.remaining_percent()),
                session_minutes: reading.session.as_ref().and_then(|window| window.window_minutes),
                long_minutes: reading.weekly.as_ref().and_then(|window| window.window_minutes),
            });
        }
        let oldest = now - RETENTION_SECONDS;
        let kept = std::mem::take(&mut self.samples)
            .into_iter()
            .map(|(id, series)| (id, series.into_iter().filter(|sample| sample.at >= oldest).collect()))
            .collect();
        self.samples = sanitized_all(kept);
    }
}

fn sanitized_all(samples: BTreeMap<String, Vec<UsageSample>>) -> BTreeMap<String, Vec<UsageSample>> {
    samples
        .into_iter()
        .map(|(id, series)| (id, sanitized(series)))
        .filter(|(_, series)| !series.is_empty())
        .collect()
}

/// Valid samples only, oldest first, one per time (the last wins), the newest `CAPACITY` of them.
fn sanitized(series: Vec<UsageSample>) -> Vec<UsageSample> {
    let by_time: BTreeMap<i64, UsageSample> =
        series.into_iter().filter(UsageSample::is_valid).map(|sample| (sample.at, sample)).collect();
    let mut sorted: Vec<UsageSample> = by_time.into_values().collect();
    sorted.drain(..sorted.len().saturating_sub(CAPACITY));
    sorted
}
