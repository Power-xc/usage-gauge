//! Locates and reads the CLIs' own login files. Tokens are read on every fetch and never kept.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use serde::de::DeserializeOwned;

use crate::http::FetchError;

fn home_dir() -> Option<PathBuf> {
    env::var_os("USERPROFILE").or_else(|| env::var_os("HOME")).map(PathBuf::from)
}

/// `%USERPROFILE%\.claude\.credentials.json`
pub fn claude_path() -> Option<PathBuf> {
    Some(home_dir()?.join(".claude").join(".credentials.json"))
}

/// `$CODEX_HOME/auth.json`, defaulting to `%USERPROFILE%\.codex\auth.json`.
pub fn codex_path() -> Option<PathBuf> {
    let home = env::var_os("CODEX_HOME").map(PathBuf::from).or_else(|| home_dir().map(|home| home.join(".codex")))?;
    Some(home.join("auth.json"))
}

/// Reads and parses a login file: a missing file means "not connected", anything unreadable or
/// malformed is reported as bad credentials without echoing the contents.
pub fn read_json<T: DeserializeOwned>(path: Option<PathBuf>) -> Result<T, FetchError> {
    let path = path.ok_or(FetchError::NotConnected)?;
    parse_file(&path)
}

fn parse_file<T: DeserializeOwned>(path: &Path) -> Result<T, FetchError> {
    let text = fs::read_to_string(path).map_err(|error| match error.kind() {
        std::io::ErrorKind::NotFound => FetchError::NotConnected,
        _ => FetchError::BadCredentials,
    })?;
    serde_json::from_str(&text).map_err(|_| FetchError::BadCredentials)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_file_is_not_connected() {
        let path = env::temp_dir().join("usage-gauge-test-missing.json");
        assert_eq!(parse_file::<serde_json::Value>(&path), Err(FetchError::NotConnected));
    }

    #[test]
    fn malformed_file_is_bad_credentials() {
        let path = env::temp_dir().join("usage-gauge-test-malformed.json");
        fs::write(&path, "{ not json").unwrap();
        let result = parse_file::<serde_json::Value>(&path);
        fs::remove_file(&path).unwrap();
        assert_eq!(result, Err(FetchError::BadCredentials));
    }
}
