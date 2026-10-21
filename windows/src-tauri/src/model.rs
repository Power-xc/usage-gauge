//! Usage model: windows, providers and the rules that turn raw percentages into what is shown.
//! Times are Unix seconds throughout, so the rules stay pure and testable.

const MINUTES_PER_HOUR: i64 = 60;
const MINUTES_PER_DAY: i64 = 24 * 60;
const SECONDS_PER_MINUTE: i64 = 60;
const WEEK_MINUTES: u32 = 10_080;
const MONTH_MINUTES: [u32; 2] = [43_200, 44_640];
const DAY_MINUTES: u32 = 1_440;

pub const LOW_THRESHOLD: f64 = 30.0;
pub const CRITICAL_THRESHOLD: f64 = 10.0;
pub const COUNTDOWN_UNKNOWN: &str = "–";
pub const COUNTDOWN_IMMINENT: &str = "곧";

/// Claude first, then Codex.
const PINNED_ORDER: [&str; 2] = ["claude", "codex"];

/// How urgent a remaining allowance is. Drives the figure colour.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize)]
#[serde(rename_all = "lowercase")]
pub enum UsageLevel {
    Comfortable,
    Low,
    Critical,
}

impl UsageLevel {
    pub fn from_remaining(remaining_percent: f64) -> Self {
        if remaining_percent <= CRITICAL_THRESHOLD {
            Self::Critical
        } else if remaining_percent <= LOW_THRESHOLD {
            Self::Low
        } else {
            Self::Comfortable
        }
    }
}

/// One rate-limit window, such as the 5-hour session or the weekly allowance.
#[derive(Debug, Clone, PartialEq)]
pub struct UsageWindow {
    pub used_percent: f64,
    pub resets_at: Option<i64>,
    pub window_minutes: Option<u32>,
}

impl UsageWindow {
    pub fn remaining_percent(&self) -> f64 {
        (100.0 - self.used_percent).clamp(0.0, 100.0)
    }

    /// Whole percent for display. Rounds to nearest, but never shows 0 while something is left
    /// or 100 while something is used, so the figure cannot claim a state the window is not in.
    pub fn display_percent(&self) -> u8 {
        let remaining = self.remaining_percent();
        if remaining > 0.0 && remaining < 1.0 {
            return 1;
        }
        if remaining > 99.0 && remaining < 100.0 {
            return 99;
        }
        remaining.round() as u8
    }

    /// The window as it stands at `now`: once its reset time has passed the allowance is full
    /// again, even before fresh numbers are fetched.
    pub fn resolved(&self, now: i64) -> Self {
        match self.resets_at {
            Some(reset) if reset <= now => Self {
                used_percent: 0.0,
                resets_at: None,
                window_minutes: self.window_minutes,
            },
            _ => self.clone(),
        }
    }

    /// "5시간", "주간", … derived from the window length; `None` when the length is unknown.
    pub fn label(&self) -> Option<String> {
        let minutes = self.window_minutes?;
        match minutes {
            WEEK_MINUTES => Some("주간".into()),
            m if MONTH_MINUTES.contains(&m) => Some("월간".into()),
            DAY_MINUTES => Some("일간".into()),
            m if m < DAY_MINUTES && m % 60 == 0 => Some(format!("{}시간", m / 60)),
            _ => None,
        }
    }

    /// 0...1, how much of the window has passed at `now`; `None` when the reset time or length is unknown.
    pub fn elapsed_fraction(&self, now: i64) -> Option<f64> {
        let (resets_at, minutes) = (self.resets_at?, self.window_minutes?);
        if minutes == 0 {
            return None;
        }
        let left = (resets_at - now) as f64 / (f64::from(minutes) * SECONDS_PER_MINUTE as f64);
        Some((1.0 - left).clamp(0.0, 1.0))
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct ProviderUsage {
    pub id: &'static str,
    pub plan: Option<String>,
    pub session: Option<UsageWindow>,
    pub weekly: Option<UsageWindow>,
    pub error_message: Option<String>,
    /// When the numbers were measured (Unix seconds).
    pub measured_at: Option<i64>,
}

impl ProviderUsage {
    /// A provider that could not be read, with the reason to show.
    pub fn failed(id: &'static str, message: String) -> Self {
        Self { id, plan: None, session: None, weekly: None, error_message: Some(message), measured_at: None }
    }

    pub fn is_available(&self) -> bool {
        self.session.is_some() || self.weekly.is_some()
    }

    pub fn title(&self) -> &'static str {
        match self.id {
            "claude" => "Claude",
            _ => "Codex",
        }
    }

    /// Both windows as they stand at `now` (see [`UsageWindow::resolved`]).
    pub fn resolved(&self, now: i64) -> Self {
        Self {
            session: self.session.as_ref().map(|window| window.resolved(now)),
            weekly: self.weekly.as_ref().map(|window| window.resolved(now)),
            ..self.clone()
        }
    }

    /// The soonest reset still ahead of `now`, so the app can refresh right after it.
    pub fn next_reset_after(&self, now: i64) -> Option<i64> {
        [&self.session, &self.weekly]
            .into_iter()
            .filter_map(|window| window.as_ref()?.resets_at)
            .filter(|reset| *reset > now)
            .min()
    }
}

/// Pinned providers in order, so the panel and the tray always list Claude first.
pub fn sorted(usage: Vec<ProviderUsage>) -> Vec<ProviderUsage> {
    let mut usage = usage;
    usage.sort_by_key(|provider| PINNED_ORDER.iter().position(|id| *id == provider.id).unwrap_or(usize::MAX));
    usage
}

/// A provider that failed this time keeps its last good reading, so one dropped request does
/// not blank the gauge. Its older `measured_at` still shows how old the numbers are.
pub fn merge(latest: Vec<ProviderUsage>, previous: &[ProviderUsage]) -> Vec<ProviderUsage> {
    latest
        .into_iter()
        .map(|usage| {
            if usage.is_available() {
                return usage;
            }
            previous
                .iter()
                .find(|kept| kept.id == usage.id && kept.is_available())
                .cloned()
                .unwrap_or(usage)
        })
        .collect()
}

/// Formats the time left until a window resets, e.g. "3시간 50분" or "2일 4시간".
pub fn countdown_text(until: Option<i64>, now: i64) -> String {
    let Some(until) = until else { return COUNTDOWN_UNKNOWN.into() };
    let minutes = (until - now) / SECONDS_PER_MINUTE;
    if minutes < 1 {
        COUNTDOWN_IMMINENT.into()
    } else if minutes >= MINUTES_PER_DAY {
        format!("{}일 {}시간", minutes / MINUTES_PER_DAY, minutes % MINUTES_PER_DAY / MINUTES_PER_HOUR)
    } else if minutes >= MINUTES_PER_HOUR {
        format!("{}시간 {}분", minutes / MINUTES_PER_HOUR, minutes % MINUTES_PER_HOUR)
    } else {
        format!("{minutes}분")
    }
}

/// Terse form for the monospaced styles, e.g. "3h 50m", "3d 4h", "47m", "<1m".
pub fn compact_countdown_text(until: Option<i64>, now: i64) -> String {
    let Some(until) = until else { return COUNTDOWN_UNKNOWN.into() };
    let minutes = (until - now) / SECONDS_PER_MINUTE;
    if minutes < 1 {
        "<1m".into()
    } else if minutes >= MINUTES_PER_DAY {
        format!("{}d {}h", minutes / MINUTES_PER_DAY, minutes % MINUTES_PER_DAY / MINUTES_PER_HOUR)
    } else if minutes >= MINUTES_PER_HOUR {
        format!("{}h {}m", minutes / MINUTES_PER_HOUR, minutes % MINUTES_PER_HOUR)
    } else {
        format!("{minutes}m")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const NOW: i64 = 1_800_000_000;

    fn window(used: f64, resets_at: Option<i64>, minutes: Option<u32>) -> UsageWindow {
        UsageWindow { used_percent: used, resets_at, window_minutes: minutes }
    }

    fn provider(id: &'static str, session: Option<UsageWindow>, measured_at: i64) -> ProviderUsage {
        ProviderUsage { id, plan: None, session, weekly: None, error_message: None, measured_at: Some(measured_at) }
    }

    #[test]
    fn display_percent_never_claims_empty_or_full_falsely() {
        assert_eq!(window(99.6, None, None).display_percent(), 1);
        assert_eq!(window(100.0, None, None).display_percent(), 0);
        assert_eq!(window(0.4, None, None).display_percent(), 99);
        assert_eq!(window(0.0, None, None).display_percent(), 100);
        assert_eq!(window(6.0, None, None).display_percent(), 94);
        assert_eq!(window(150.0, None, None).remaining_percent(), 0.0);
        assert_eq!(window(-5.0, None, None).remaining_percent(), 100.0);
    }

    #[test]
    fn window_past_its_reset_reads_full() {
        let spent = window(80.0, Some(NOW - 1), Some(300));
        let resolved = spent.resolved(NOW);
        assert_eq!(resolved.display_percent(), 100);
        assert_eq!(resolved.resets_at, None);
        assert_eq!(resolved.window_minutes, Some(300));
        let ahead = window(80.0, Some(NOW + 60), Some(300));
        assert_eq!(ahead.resolved(NOW), ahead);
    }

    #[test]
    fn levels_follow_thresholds() {
        assert_eq!(UsageLevel::from_remaining(31.0), UsageLevel::Comfortable);
        assert_eq!(UsageLevel::from_remaining(30.0), UsageLevel::Low);
        assert_eq!(UsageLevel::from_remaining(10.0), UsageLevel::Critical);
    }

    #[test]
    fn labels_come_from_window_length() {
        assert_eq!(window(0.0, None, Some(300)).label().as_deref(), Some("5시간"));
        assert_eq!(window(0.0, None, Some(10_080)).label().as_deref(), Some("주간"));
        assert_eq!(window(0.0, None, Some(43_200)).label().as_deref(), Some("월간"));
        assert_eq!(window(0.0, None, Some(90)).label(), None);
        assert_eq!(window(0.0, None, None).label(), None);
    }

    #[test]
    fn elapsed_fraction_tracks_the_window() {
        let half = window(0.0, Some(NOW + 150 * 60), Some(300));
        assert_eq!(half.elapsed_fraction(NOW), Some(0.5));
        assert_eq!(window(0.0, None, Some(300)).elapsed_fraction(NOW), None);
        assert_eq!(window(0.0, Some(NOW - 10), Some(300)).elapsed_fraction(NOW), Some(1.0));
    }

    #[test]
    fn failed_provider_keeps_last_good_reading() {
        let good = provider("claude", Some(window(6.0, None, Some(300))), NOW - 600);
        let failed = ProviderUsage::failed("claude", "x".into());
        let merged = merge(vec![failed.clone()], std::slice::from_ref(&good));
        assert_eq!(merged, vec![good.clone()]);
        assert_eq!(merge(vec![failed.clone()], &[]), vec![failed]);
        let fresh = provider("claude", Some(window(10.0, None, Some(300))), NOW);
        assert_eq!(merge(vec![fresh.clone()], &[good]), vec![fresh]);
    }

    #[test]
    fn claude_is_listed_before_codex() {
        let order = sorted(vec![provider("codex", None, 0), provider("claude", None, 0)]);
        assert_eq!(order.iter().map(|p| p.id).collect::<Vec<_>>(), vec!["claude", "codex"]);
    }

    #[test]
    fn countdown_reads_like_the_macos_app() {
        assert_eq!(countdown_text(None, NOW), "–");
        assert_eq!(countdown_text(Some(NOW + 30), NOW), "곧");
        assert_eq!(countdown_text(Some(NOW + 47 * 60), NOW), "47분");
        assert_eq!(countdown_text(Some(NOW + (3 * 60 + 50) * 60), NOW), "3시간 50분");
        assert_eq!(countdown_text(Some(NOW + (3 * 24 * 60) * 60), NOW), "3일 0시간");
        assert_eq!(countdown_text(Some(NOW + (6 * 24 + 16) * 3600), NOW), "6일 16시간");
    }

    #[test]
    fn compact_countdown_is_terse() {
        assert_eq!(compact_countdown_text(None, NOW), "–");
        assert_eq!(compact_countdown_text(Some(NOW + 30), NOW), "<1m");
        assert_eq!(compact_countdown_text(Some(NOW + 47 * 60), NOW), "47m");
        assert_eq!(compact_countdown_text(Some(NOW + (3 * 60 + 50) * 60), NOW), "3h 50m");
        assert_eq!(compact_countdown_text(Some(NOW + (3 * 24 * 60) * 60), NOW), "3d 0h");
        assert_eq!(compact_countdown_text(Some(NOW + (3 * 24 + 4) * 3600), NOW), "3d 4h");
    }

    #[test]
    fn next_reset_ignores_resets_already_passed() {
        let usage = ProviderUsage {
            weekly: Some(window(0.0, Some(NOW + 500), Some(10_080))),
            ..provider("claude", Some(window(0.0, Some(NOW - 5), Some(300))), NOW)
        };
        assert_eq!(usage.next_reset_after(NOW), Some(NOW + 500));
    }
}
