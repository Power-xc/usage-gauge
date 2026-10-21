//! The single outbound path for tokens: HTTPS GET to the two usage hosts, nothing else.

use std::time::Duration;

use serde::de::DeserializeOwned;

/// Hosts a bearer token may be sent to.
pub const ALLOWED_HOSTS: [&str; 2] = ["api.anthropic.com", "chatgpt.com"];
const REQUEST_TIMEOUT: Duration = Duration::from_secs(20);

/// Why a provider could not be read; each variant maps to a user-facing message in `providers`.
#[derive(Debug, PartialEq)]
pub enum FetchError {
    /// No login file, or it holds no usable token.
    NotConnected,
    /// The login file exists but cannot be read.
    BadCredentials,
    /// The server rejected the token (401/403).
    Unauthorized,
    RateLimited,
    Network,
    BadResponse,
}

/// GET `url` with the given headers and decode the JSON body. The URL must be an HTTPS URL on an
/// allowed host, and redirects are never followed, so a token cannot be sent anywhere else.
pub fn get_json<T: DeserializeOwned>(url: &str, headers: &[(&str, &str)]) -> Result<T, FetchError> {
    let host = url.strip_prefix("https://").and_then(|rest| rest.split('/').next());
    if !host.is_some_and(|host| ALLOWED_HOSTS.contains(&host)) {
        return Err(FetchError::BadResponse);
    }
    let agent: ureq::Agent = ureq::Agent::config_builder()
        .max_redirects(0)
        .http_status_as_error(false)
        .https_only(true)
        .timeout_global(Some(REQUEST_TIMEOUT))
        .build()
        .into();
    let mut request = agent.get(url).header("Accept", "application/json");
    for (name, value) in headers {
        request = request.header(*name, *value);
    }
    let mut response = request.call().map_err(|_| FetchError::Network)?;
    match response.status().as_u16() {
        200 => response.body_mut().read_json().map_err(|_| FetchError::BadResponse),
        401 | 403 => Err(FetchError::Unauthorized),
        429 => Err(FetchError::RateLimited),
        _ => Err(FetchError::BadResponse),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn refuses_hosts_and_schemes_outside_the_allow_list() {
        for url in ["http://api.anthropic.com/x", "https://evil.example/x", "https://api.anthropic.com.evil.example/x"] {
            assert_eq!(get_json::<serde_json::Value>(url, &[]), Err(FetchError::BadResponse), "{url}");
        }
    }
}
