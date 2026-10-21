//! Where usage comes from: each tool's own login and its official usage endpoint.

mod claude;
mod codex;

use std::thread;

use crate::http::FetchError;
use crate::model::{sorted, ProviderUsage};

/// Fetches both providers in parallel; a failure only affects its own provider.
pub fn fetch_all(now: i64) -> Vec<ProviderUsage> {
    let (claude, codex) = thread::scope(|scope| {
        let codex = scope.spawn(|| codex::fetch(now));
        (claude::fetch(now), codex.join().unwrap_or_else(|_| failure("codex", FetchError::Network)))
    });
    sorted(vec![claude, codex])
}

fn failure(id: &'static str, error: FetchError) -> ProviderUsage {
    ProviderUsage::failed(id, message(id, &error))
}

/// User-facing reason, in Korean, naming the tool whose login needs attention.
fn message(id: &str, error: &FetchError) -> String {
    let (tool, login) = match id {
        "claude" => ("Claude", "Claude Code"),
        _ => ("Codex", "Codex CLI"),
    };
    match error {
        FetchError::NotConnected => format!("{login}에 로그인하면 연결돼요"),
        FetchError::BadCredentials => format!("{tool} 로그인 정보를 읽을 수 없어요"),
        FetchError::Unauthorized => format!("{login}에서 다시 로그인하세요"),
        FetchError::RateLimited => "요청이 많아요. 잠시 후 다시 시도해요".into(),
        FetchError::Network => "네트워크에 연결할 수 없어요".into(),
        FetchError::BadResponse => format!("{tool} 응답을 읽을 수 없어요"),
    }
}

/// "max" → "Max", for the quiet plan caption.
fn capitalized(text: &str) -> String {
    let mut chars = text.chars();
    chars.next().map(|first| first.to_uppercase().chain(chars).collect()).unwrap_or_default()
}
