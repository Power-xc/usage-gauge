//! Mirrors the history checks of the macOS app's `CoreChecks`.

use std::collections::BTreeMap;
use std::fs;

use super::*;
use crate::model::UsageWindow;

const NOW: i64 = 1_800_000_000;
const HOUR: i64 = 3600;

fn window(used: f64, resets_in: Option<i64>, minutes: Option<u32>) -> UsageWindow {
    UsageWindow { used_percent: used, resets_at: resets_in.map(|seconds| NOW + seconds), window_minutes: minutes }
}

fn usage(id: &'static str, session: Option<UsageWindow>, weekly: Option<UsageWindow>, measured_at: Option<i64>) -> ProviderUsage {
    ProviderUsage { id, plan: None, session, weekly, error_message: None, measured_at }
}

fn claude(remaining: f64, long: Option<f64>, resets_in: i64) -> ProviderUsage {
    usage(
        "claude",
        Some(window(100.0 - remaining, Some(resets_in), Some(300))),
        long.map(|share| window(100.0 - share, None, Some(10_080))),
        None,
    )
}

fn claude_now(remaining: f64) -> ProviderUsage {
    claude(remaining, None, 3 * HOUR)
}

fn sample(at: i64, session: Option<f64>) -> UsageSample {
    UsageSample { at, session, long: None, session_minutes: None, long_minutes: None }
}

/// A history of the 300-minute window with a sample every `step` seconds, the last one at `end`.
fn drained(remaining: &[f64], step: i64, end: i64) -> UsageHistory {
    let mut history = UsageHistory::default();
    for (offset, value) in remaining.iter().enumerate() {
        history.record(&[claude_now(*value)], end - step * (remaining.len() - 1 - offset) as i64);
    }
    history
}

fn hour_window(remaining: f64) -> UsageWindow {
    claude_now(remaining).session.unwrap()
}

fn series_len(history: &UsageHistory, id: &str) -> usize {
    history.samples().get(id).map_or(0, Vec::len)
}

#[test]
fn only_available_providers_are_recorded() {
    let mut history = UsageHistory::default();
    history.record(&[claude(80.0, Some(60.0), 3 * HOUR), usage("gemini", None, None, None)], NOW);
    assert_eq!(history.samples().keys().collect::<Vec<_>>(), ["claude"]);
}

#[test]
fn samples_are_spaced_pruned_and_capped() {
    let mut history = UsageHistory::default();
    history.record(&[claude_now(80.0)], NOW);
    history.record(&[claude_now(79.0)], NOW + 49);
    assert_eq!(series_len(&history, "claude"), 1, "a second sample under 50 s later is skipped");
    history.record(&[claude_now(79.0)], NOW + 50);
    assert_eq!(series_len(&history, "claude"), 2, "a sample 50 s later is kept");
    history.record(&[claude_now(70.0)], NOW + 27 * HOUR);
    assert_eq!(series_len(&history, "claude"), 1, "samples older than 26 h are pruned");

    let mut crowded = UsageHistory::default();
    for minute in 0..1100 {
        crowded.record(&[claude_now(50.0)], NOW + minute * 60);
    }
    let series = &crowded.samples()["claude"];
    assert_eq!(series.len(), 1000, "a series is capped at 1 000 samples");
    assert_eq!(series.last().unwrap().at, NOW + 1099 * 60, "the cap keeps the newest samples");
}

#[test]
fn burn_rate_and_projected_empty_follow_the_drain() {
    let drain = drained(&[90.0, 85.0, 80.0, 75.0, 70.0, 65.0, 60.0, 55.0, 50.0, 45.0, 40.0, 35.0, 30.0], 300, NOW);
    let window = hour_window(30.0);
    assert_eq!(drain.samples_in("claude", &window, NOW).len(), 13, "samples inside the period are returned");
    assert!(drain.samples_in("claude", &UsageWindow { used_percent: 0.0, resets_at: None, window_minutes: Some(300) }, NOW).is_empty());
    assert!((drain.burn_rate("claude", &window, NOW).unwrap() - 60.0).abs() < 0.001, "burn rate is the % used per hour");
    assert_eq!(drain.projected_empty("claude", &window, NOW), Some(NOW + 1800), "30 % left at 60 %/h runs out in 30 min");

    let lasting = drained(&[100.0, 99.0, 98.0, 97.0, 96.0, 95.0], 300, NOW);
    let slow = hour_window(95.0);
    assert!((lasting.burn_rate("claude", &slow, NOW).unwrap() - 12.0).abs() < 0.001, "slow burn rate");
    assert_eq!(lasting.projected_empty("claude", &slow, NOW), None, "a window that lasts past its reset has no empty time");
}

#[test]
fn burn_rate_needs_data_and_use() {
    let window = hour_window(30.0);
    assert_eq!(drained(&[90.0, 85.0], 300, NOW).burn_rate("claude", &window, NOW), None, "under 10 min of data");
    assert_eq!(drained(&[50.0; 4], 300, NOW).burn_rate("claude", &window, NOW), None, "nothing used");
    assert_eq!(drained(&[30.0, 40.0, 50.0, 60.0], 300, NOW).burn_rate("claude", &window, NOW), None, "rises are not usage");
}

#[test]
fn a_reset_starts_a_fresh_series() {
    let mut history = drained(&[20.0, 10.0, 5.0], 60, NOW - 600);
    history.record(&[claude(100.0, None, 300 * 60)], NOW);
    let next_period = claude(100.0, None, 300 * 60).session.unwrap();
    assert_eq!(history.samples_in("claude", &next_period, NOW).len(), 1, "only the new period's samples count");
}

#[test]
fn slices_sum_drops_and_carry_remaining() {
    let sliced = drained(&[100.0, 90.0, 80.0, 85.0, 60.0], 1200, NOW - 300);
    // The window started 90 min ago.
    let started = window(40.0, Some(7 * HOUR / 2), Some(300));
    let used = sliced.used_per_slice("claude", &started, NOW, 5);
    assert_eq!((used.len(), used[0], used[1], used[2], used[4]), (5, Some(20.0), Some(25.0), None, None));
    let quiet = drained(&[100.0, 90.0, 90.0, 90.0], 1200, NOW - 300);
    assert_eq!(quiet.used_per_slice("claude", &started, NOW, 5)[1], Some(0.0), "a past slice without drops is 0");

    let remaining = sliced.remaining_per_slice("claude", &started, NOW, 5);
    assert_eq!((remaining[0], remaining[1], remaining[2]), (Some(80.0), Some(60.0), None));
    let carried = drained(&[100.0, 90.0, 80.0], 1200, NOW - 3000).remaining_per_slice("claude", &started, NOW, 5);
    assert_eq!((carried[0], carried[1]), (Some(80.0), Some(80.0)), "the last value carries into a slice without samples");
    let late = drained(&[80.0, 70.0], 600, NOW).remaining_per_slice("claude", &started, NOW, 5);
    assert_eq!((late[0], late[1]), (None, Some(70.0)), "nothing before the first sample");
    assert!(drained(&[50.0], 60, NOW).used_per_slice("claude", &started, NOW, 0).is_empty(), "zero slices is empty");
}

#[test]
fn a_window_reads_the_series_recorded_with_its_length() {
    let copilot = usage(
        "copilot",
        Some(window(30.0, Some(3 * 24 * HOUR), Some(10_080))),
        Some(window(80.0, Some(20 * 24 * HOUR), Some(43_200))),
        None,
    );
    let mut history = UsageHistory::default();
    history.record(std::slice::from_ref(&copilot), NOW);
    let points = |window: &UsageWindow| history.points("copilot", window, NOW).iter().map(|p| p.remaining).collect::<Vec<_>>();
    assert_eq!(points(copilot.session.as_ref().unwrap()), [70.0]);
    assert_eq!(points(copilot.weekly.as_ref().unwrap()), [20.0], "the long window reads the long series");
}

#[test]
fn samples_are_dated_when_measured_and_read_as_of_then() {
    let cached = usage("claude", Some(window(60.0, Some(-60), Some(300))), None, Some(NOW - 30));
    let mut history = UsageHistory::default();
    history.record(&[cached], NOW);
    let first = &history.samples()["claude"][0];
    assert_eq!(first.at, NOW - 30, "a sample is dated when it was measured");
    assert_eq!(first.session, Some(100.0), "a window whose reset had passed is recorded as full");
}

#[test]
fn invalid_samples_are_dropped_and_duplicates_keep_the_last() {
    let dirty = UsageHistory::from_samples(BTreeMap::from([(
        "claude".to_owned(),
        vec![
            sample(NOW, Some(50.0)),
            sample(NOW, Some(40.0)),
            sample(NOW - 60, Some(f64::NAN)),
            sample(NOW - 120, Some(140.0)),
            sample(NOW - 180, None),
            sample(NOW - 240, Some(30.0)),
        ],
    )]));
    let shares: Vec<_> = dirty.samples()["claude"].iter().map(|sample| sample.session).collect();
    assert_eq!(shares, [Some(30.0), Some(40.0)]);
}

mod disk {
    use super::*;

    fn scratch(name: &str) -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!("usage-gauge-test-history-{name}"));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn history_with_file(name: &str, text: &str) -> UsageHistory {
        let dir = scratch(name);
        fs::write(dir.join("history.json"), text).unwrap();
        let loaded = UsageHistory::load(&dir, NOW);
        fs::remove_dir_all(&dir).unwrap();
        loaded
    }

    #[test]
    fn history_survives_a_round_trip() {
        let dir = scratch("round-trip");
        let stored = UsageHistory::from_samples(BTreeMap::from([(
            "claude".to_owned(),
            vec![sample(NOW - 600, Some(80.0)), UsageSample { long: Some(60.0), ..sample(NOW - 300, Some(70.0)) }],
        )]));
        stored.save(&dir);
        assert_eq!(UsageHistory::load(&dir, NOW), stored);
        assert!(!dir.join("history.json.tmp").exists(), "the temporary file is renamed away");
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn a_missing_file_is_an_empty_history() {
        let dir = scratch("missing");
        assert_eq!(UsageHistory::load(&dir, NOW), UsageHistory::default());
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn loading_drops_future_out_of_range_and_malformed_samples() {
        let text = format!(
            r#"{{"samples": {{"claude": [{{"at": {past}, "session": 10}}, {{"at": {future}, "session": 20}}, {{"at": 5, "session": 500}}, {{"nope": true}}]}}}}"#,
            past = NOW - 60,
            future = NOW + 7200,
        );
        let shares: Vec<_> = history_with_file("mixed", &text).samples()["claude"].iter().map(|s| s.session).collect();
        assert_eq!(shares, [Some(10.0)]);
    }

    #[test]
    fn corrupt_or_wrongly_shaped_files_load_empty() {
        assert_eq!(history_with_file("corrupt", "not json"), UsageHistory::default());
        assert_eq!(history_with_file("shape", r#"{"samples": 3}"#), UsageHistory::default());
    }
}
