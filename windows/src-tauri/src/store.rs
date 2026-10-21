//! Latest usage and the rules for when to fetch again. Pure state: the app layer runs the fetches.

use crate::history::UsageHistory;
use crate::model::{merge, ProviderUsage};

/// A refresh asked for (panel shown, woken from sleep) is skipped when the data is newer than this.
pub const FRESHNESS_SECONDS: i64 = 60;
/// Periodic refresh interval.
pub const REFRESH_INTERVAL_SECONDS: i64 = 120;
/// A tick this much later than expected means the machine slept in between.
pub const RESUME_GAP_SECONDS: i64 = 45;

#[derive(Debug, Default)]
pub struct Store {
    fetched: Vec<ProviderUsage>,
    last_fetched: Option<i64>,
    last_attempt: Option<i64>,
    now: i64,
    is_fetching: bool,
    history: UsageHistory,
}

impl Store {
    pub fn with_history(history: UsageHistory) -> Self {
        Self { history, ..Self::default() }
    }

    pub fn history(&self) -> &UsageHistory {
        &self.history
    }

    pub fn now(&self) -> i64 {
        self.now
    }

    /// Usage as it stands now: windows whose reset has passed already read as full.
    pub fn providers(&self) -> Vec<ProviderUsage> {
        self.fetched.iter().map(|usage| usage.resolved(self.now)).collect()
    }

    /// When the numbers were measured: the oldest provider reading, or the last fetch.
    pub fn measured_at(&self) -> Option<i64> {
        self.fetched.iter().filter_map(|usage| usage.measured_at).min().or(self.last_fetched)
    }

    /// Claims the right to fetch; `false` while another fetch is running.
    pub fn begin_fetch(&mut self, now: i64) -> bool {
        if self.is_fetching {
            return false;
        }
        self.is_fetching = true;
        self.last_attempt = Some(now);
        true
    }

    pub fn finish_fetch(&mut self, latest: Vec<ProviderUsage>, now: i64) {
        self.is_fetching = false;
        self.now = now;
        self.history.record(&latest, now);
        self.fetched = merge(latest, &self.fetched);
        self.last_fetched = Some(now);
    }

    pub fn is_stale(&self, now: i64) -> bool {
        self.last_fetched.is_none_or(|fetched| now - fetched >= FRESHNESS_SECONDS)
    }

    /// Advances the clock and says whether numbers should be fetched: when a window's reset has
    /// just passed, when the machine woke from sleep, or when the periodic interval is due.
    pub fn tick(&mut self, now: i64) -> bool {
        let previous = self.now;
        self.now = now;
        let reset_passed = self.fetched.iter().any(|usage| usage.next_reset_after(previous).is_some_and(|reset| reset <= now));
        let resumed = previous > 0 && now - previous > RESUME_GAP_SECONDS && self.is_stale(now);
        let due = self.last_attempt.is_none_or(|attempt| now - attempt >= REFRESH_INTERVAL_SECONDS);
        reset_passed || resumed || due
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::UsageWindow;

    fn reading(resets_at: i64, measured_at: i64) -> ProviderUsage {
        ProviderUsage {
            id: "claude",
            plan: None,
            session: Some(UsageWindow { used_percent: 10.0, resets_at: Some(resets_at), window_minutes: Some(300) }),
            weekly: None,
            error_message: None,
            measured_at: Some(measured_at),
        }
    }

    #[test]
    fn failed_refresh_keeps_the_last_good_reading_and_its_age() {
        let mut store = Store::default();
        assert!(store.begin_fetch(1000));
        store.finish_fetch(vec![reading(9000, 1000)], 1000);
        assert!(store.begin_fetch(1100));
        store.finish_fetch(vec![ProviderUsage::failed("claude", "x".into())], 1100);
        assert_eq!(store.providers()[0].session.as_ref().unwrap().used_percent, 10.0);
        assert_eq!(store.measured_at(), Some(1000));
    }

    #[test]
    fn only_one_fetch_runs_at_a_time() {
        let mut store = Store::default();
        assert!(store.begin_fetch(0));
        assert!(!store.begin_fetch(1));
    }

    #[test]
    fn tick_fetches_when_a_reset_passes_or_the_interval_is_due() {
        let mut store = Store::default();
        store.begin_fetch(1000);
        store.finish_fetch(vec![reading(1030, 1000)], 1000);
        assert!(!store.tick(1015));
        assert!(store.tick(1031), "reset just passed");
        let mut store = Store::default();
        store.begin_fetch(1000);
        store.finish_fetch(vec![reading(90_000, 1000)], 1000);
        for at in (1015..1000 + REFRESH_INTERVAL_SECONDS).step_by(15) {
            assert!(!store.tick(at), "not yet due at {at}");
        }
        assert!(store.tick(1000 + REFRESH_INTERVAL_SECONDS), "interval due");
    }

    #[test]
    fn tick_after_a_long_gap_counts_as_resume() {
        let mut store = Store::default();
        store.begin_fetch(1000);
        store.finish_fetch(vec![reading(90_000, 1000)], 1000);
        store.tick(1050);
        store.begin_fetch(1050);
        assert!(store.tick(1050 + RESUME_GAP_SECONDS + 1));
    }
}
