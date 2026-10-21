//! What the webview receives: computed readings only, never credentials.

use serde::Serialize;

use crate::model::{countdown_text, ProviderUsage, UsageLevel, UsageWindow};
use crate::store::Store;

const DEFAULT_SESSION_LABEL: &str = "단기";
const DEFAULT_WEEKLY_LABEL: &str = "장기";

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WindowView {
    pub display_percent: u8,
    pub remaining_percent: f64,
    pub elapsed_fraction: Option<f64>,
    pub label: String,
    pub countdown: String,
    pub level: UsageLevel,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProviderView {
    pub id: &'static str,
    pub title: &'static str,
    pub plan: Option<String>,
    pub session: Option<WindowView>,
    pub weekly: Option<WindowView>,
    /// Why the provider is not connected; `None` while it has readings.
    pub message: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UsageView {
    pub providers: Vec<ProviderView>,
    /// Epoch milliseconds of the oldest provider reading.
    pub measured_at: Option<i64>,
}

fn window_view(window: &UsageWindow, default_label: &str, now: i64) -> WindowView {
    WindowView {
        display_percent: window.display_percent(),
        remaining_percent: window.remaining_percent(),
        elapsed_fraction: window.elapsed_fraction(now),
        label: window.label().unwrap_or_else(|| default_label.into()),
        countdown: countdown_text(window.resets_at, now),
        level: UsageLevel::from_remaining(window.remaining_percent()),
    }
}

fn provider_view(usage: &ProviderUsage, now: i64) -> ProviderView {
    let is_available = usage.is_available();
    ProviderView {
        id: usage.id,
        title: usage.title(),
        plan: usage.plan.clone(),
        session: usage.session.as_ref().map(|window| window_view(window, DEFAULT_SESSION_LABEL, now)),
        weekly: usage.weekly.as_ref().map(|window| window_view(window, DEFAULT_WEEKLY_LABEL, now)),
        message: (!is_available).then(|| usage.error_message.clone().unwrap_or_default()),
    }
}

pub fn usage_view(store: &Store) -> UsageView {
    let now = store.now();
    UsageView {
        providers: store.providers().iter().map(|usage| provider_view(usage, now)).collect(),
        measured_at: store.measured_at().map(|seconds| seconds * 1000),
    }
}

/// "Claude 94% · Codex 8%": the short window of each provider, for the tray tooltip.
pub fn tooltip(view: &UsageView) -> String {
    let parts: Vec<String> = view
        .providers
        .iter()
        .map(|provider| match &provider.session {
            Some(session) => format!("{} {}%", provider.title, session.display_percent),
            None => format!("{} –", provider.title),
        })
        .collect();
    if parts.is_empty() { "UsageGauge".into() } else { parts.join(" · ") }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn provider(title: &'static str, percent: Option<u8>) -> ProviderView {
        let session = percent.map(|display_percent| WindowView {
            display_percent,
            remaining_percent: f64::from(display_percent),
            elapsed_fraction: None,
            label: "5시간".into(),
            countdown: "1분".into(),
            level: UsageLevel::Comfortable,
        });
        ProviderView { id: "claude", title, plan: None, session, weekly: None, message: None }
    }

    #[test]
    fn tooltip_lists_each_provider_short_window() {
        let view = UsageView { providers: vec![provider("Claude", Some(94)), provider("Codex", Some(8))], measured_at: None };
        assert_eq!(tooltip(&view), "Claude 94% · Codex 8%");
        let view = UsageView { providers: vec![provider("Claude", Some(94)), provider("Codex", None)], measured_at: None };
        assert_eq!(tooltip(&view), "Claude 94% · Codex –");
    }
}
