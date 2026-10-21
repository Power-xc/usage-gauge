//! Claude: the Claude Code login and `GET /api/oauth/usage` (the official usage endpoint).

use chrono::DateTime;
use serde::Deserialize;

use super::{capitalized, failure};
use crate::credentials;
use crate::http::{get_json, FetchError};
use crate::model::{ProviderUsage, UsageWindow};

const USAGE_URL: &str = "https://api.anthropic.com/api/oauth/usage";
const BETA_HEADER: &str = "oauth-2025-04-20";
const SESSION_MINUTES: u32 = 5 * 60;
const WEEK_MINUTES: u32 = 7 * 24 * 60;

#[derive(Deserialize)]
struct Credentials {
    #[serde(rename = "claudeAiOauth")]
    oauth: Option<OAuth>,
}

#[derive(Deserialize)]
struct OAuth {
    #[serde(rename = "accessToken")]
    access_token: Option<String>,
    #[serde(rename = "subscriptionType")]
    subscription_type: Option<String>,
}

#[derive(Deserialize)]
struct UsageResponse {
    five_hour: Option<RawWindow>,
    seven_day: Option<RawWindow>,
}

/// `utilization` is the percent used; `resets_at` is ISO 8601.
#[derive(Deserialize)]
struct RawWindow {
    utilization: Option<f64>,
    resets_at: Option<String>,
}

pub fn fetch(now: i64) -> ProviderUsage {
    read(now).unwrap_or_else(|error| failure("claude", error))
}

fn read(now: i64) -> Result<ProviderUsage, FetchError> {
    let credentials: Credentials = credentials::read_json(credentials::claude_path())?;
    let oauth = credentials.oauth.ok_or(FetchError::NotConnected)?;
    let token = oauth.access_token.filter(|token| !token.is_empty()).ok_or(FetchError::NotConnected)?;
    let bearer = format!("Bearer {token}");
    let response: UsageResponse =
        get_json(USAGE_URL, &[("Authorization", &bearer), ("anthropic-beta", BETA_HEADER)])?;
    Ok(usage_from(response, oauth.subscription_type.as_deref(), now))
}

fn usage_from(response: UsageResponse, plan: Option<&str>, now: i64) -> ProviderUsage {
    ProviderUsage {
        id: "claude",
        plan: plan.filter(|plan| !plan.is_empty()).map(capitalized),
        session: response.five_hour.and_then(|raw| window(raw, SESSION_MINUTES)),
        weekly: response.seven_day.and_then(|raw| window(raw, WEEK_MINUTES)),
        error_message: None,
        measured_at: Some(now),
    }
}

/// The API does not report window lengths, so they are fixed per window.
fn window(raw: RawWindow, minutes: u32) -> Option<UsageWindow> {
    Some(UsageWindow {
        used_percent: raw.utilization?,
        resets_at: raw.resets_at.and_then(|text| DateTime::parse_from_rfc3339(&text).ok()).map(|date| date.timestamp()),
        window_minutes: Some(minutes),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIXTURE: &str = r#"{
        "five_hour": { "utilization": 6.0, "resets_at": "2026-10-21T08:00:00.123456+00:00" },
        "seven_day": { "utilization": 63.5, "resets_at": "2026-10-24T05:00:00Z" },
        "seven_day_opus": null,
        "extra_usage": { "is_enabled": false }
    }"#;

    #[test]
    fn parses_both_windows_and_plan() {
        let response: UsageResponse = serde_json::from_str(FIXTURE).unwrap();
        let usage = usage_from(response, Some("max"), 100);
        let session = usage.session.unwrap();
        assert_eq!(session.used_percent, 6.0);
        assert_eq!(session.window_minutes, Some(300));
        assert_eq!(session.resets_at, Some(1_792_569_600));
        assert_eq!(usage.weekly.unwrap().resets_at, Some(1_792_818_000));
        assert_eq!(usage.plan.as_deref(), Some("Max"));
        assert_eq!(usage.measured_at, Some(100));
    }

    #[test]
    fn window_without_utilization_is_skipped() {
        let response: UsageResponse =
            serde_json::from_str(r#"{ "five_hour": { "resets_at": null }, "seven_day": null }"#).unwrap();
        let usage = usage_from(response, None, 0);
        assert!(!usage.is_available());
    }

    #[test]
    fn credentials_expose_only_the_oauth_block() {
        let parsed: Credentials =
            serde_json::from_str(r#"{ "claudeAiOauth": { "accessToken": "t", "subscriptionType": "pro" } }"#).unwrap();
        assert_eq!(parsed.oauth.unwrap().subscription_type.as_deref(), Some("pro"));
    }
}
