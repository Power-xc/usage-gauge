//! Codex: the Codex CLI login and `GET /backend-api/wham/usage` (the official usage endpoint).

use serde::Deserialize;

use super::{capitalized, failure};
use crate::credentials;
use crate::http::{get_json, FetchError};
use crate::model::{ProviderUsage, UsageWindow};

const USAGE_URL: &str = "https://chatgpt.com/backend-api/wham/usage";
const SECONDS_PER_MINUTE: u32 = 60;

#[derive(Deserialize)]
struct AuthFile {
    tokens: Option<Tokens>,
}

#[derive(Deserialize)]
struct Tokens {
    access_token: Option<String>,
    account_id: Option<String>,
}

#[derive(Deserialize)]
struct UsageResponse {
    plan_type: Option<String>,
    rate_limit: Option<RateLimit>,
}

#[derive(Deserialize)]
struct RateLimit {
    primary_window: Option<RawWindow>,
    secondary_window: Option<RawWindow>,
}

/// `reset_at` is Unix seconds.
#[derive(Deserialize)]
struct RawWindow {
    used_percent: f64,
    limit_window_seconds: Option<u32>,
    reset_at: Option<i64>,
}

pub fn fetch(now: i64) -> ProviderUsage {
    read(now).unwrap_or_else(|error| failure("codex", error))
}

fn read(now: i64) -> Result<ProviderUsage, FetchError> {
    let auth: AuthFile = credentials::read_json(credentials::codex_path())?;
    let tokens = auth.tokens.ok_or(FetchError::NotConnected)?;
    let token = tokens.access_token.filter(|token| !token.is_empty()).ok_or(FetchError::NotConnected)?;
    let bearer = format!("Bearer {token}");
    let mut headers = vec![("Authorization", bearer.as_str())];
    if let Some(account) = tokens.account_id.as_deref().filter(|account| !account.is_empty()) {
        headers.push(("ChatGPT-Account-Id", account));
    }
    let response: UsageResponse = get_json(USAGE_URL, &headers)?;
    Ok(usage_from(response, now))
}

fn usage_from(response: UsageResponse, now: i64) -> ProviderUsage {
    let limit = response.rate_limit;
    let (primary, secondary) = match limit {
        Some(limit) => (limit.primary_window, limit.secondary_window),
        None => (None, None),
    };
    ProviderUsage {
        id: "codex",
        plan: response.plan_type.filter(|plan| !plan.is_empty()).map(|plan| capitalized(&plan)),
        session: primary.map(window),
        weekly: secondary.map(window),
        error_message: None,
        measured_at: Some(now),
    }
}

fn window(raw: RawWindow) -> UsageWindow {
    UsageWindow {
        used_percent: raw.used_percent,
        resets_at: raw.reset_at,
        window_minutes: raw.limit_window_seconds.map(|seconds| seconds / SECONDS_PER_MINUTE),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIXTURE: &str = r#"{
        "plan_type": "plus",
        "rate_limit": {
            "allowed": true,
            "primary_window": { "used_percent": 92, "limit_window_seconds": 18000, "reset_after_seconds": 2820, "reset_at": 1792562820 },
            "secondary_window": { "used_percent": 74, "limit_window_seconds": 604800, "reset_at": 1793000000 }
        },
        "credits": { "has_credits": false }
    }"#;

    #[test]
    fn parses_primary_and_secondary_windows() {
        let response: UsageResponse = serde_json::from_str(FIXTURE).unwrap();
        let usage = usage_from(response, 5);
        let session = usage.session.unwrap();
        assert_eq!(session.used_percent, 92.0);
        assert_eq!(session.window_minutes, Some(300));
        assert_eq!(session.resets_at, Some(1_792_562_820));
        assert_eq!(usage.weekly.unwrap().window_minutes, Some(10_080));
        assert_eq!(usage.plan.as_deref(), Some("Plus"));
    }

    #[test]
    fn missing_rate_limit_leaves_the_provider_unavailable() {
        let response: UsageResponse = serde_json::from_str(r#"{ "plan_type": "free" }"#).unwrap();
        assert!(!usage_from(response, 0).is_available());
    }

    #[test]
    fn auth_file_tokens_parse() {
        let auth: AuthFile =
            serde_json::from_str(r#"{ "OPENAI_API_KEY": null, "tokens": { "access_token": "a", "account_id": "b" } }"#)
                .unwrap();
        assert_eq!(auth.tokens.unwrap().account_id.as_deref(), Some("b"));
    }
}
