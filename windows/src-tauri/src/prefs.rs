//! Remembered panel settings, kept as a small JSON file in the app config directory.

use std::fs;
use std::path::Path;

use serde::{Deserialize, Serialize};

pub const OPACITY_MIN: f64 = 0.3;
pub const OPACITY_MAX: f64 = 1.0;
const FILE_NAME: &str = "prefs.json";

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct Prefs {
    pub opacity: f64,
    pub panel_visible: bool,
    /// Top-left of the panel in physical pixels; `None` until the user moves it.
    pub position: Option<(i32, i32)>,
}

impl Default for Prefs {
    fn default() -> Self {
        Self { opacity: OPACITY_MAX, panel_visible: true, position: None }
    }
}

impl Prefs {
    /// Loads the saved settings; a missing or unreadable file yields the defaults.
    pub fn load(dir: &Path) -> Self {
        let Ok(text) = fs::read_to_string(dir.join(FILE_NAME)) else { return Self::default() };
        let mut prefs: Self = serde_json::from_str(&text).unwrap_or_else(|error| {
            eprintln!("usage-gauge: ignoring unreadable {FILE_NAME}: {error}");
            Self::default()
        });
        prefs.opacity = clamp_opacity(prefs.opacity);
        prefs
    }

    pub fn save(&self, dir: &Path) {
        let written = fs::create_dir_all(dir)
            .and_then(|()| fs::write(dir.join(FILE_NAME), serde_json::to_string(self).unwrap_or_default()));
        if let Err(error) = written {
            eprintln!("usage-gauge: could not save {FILE_NAME}: {error}");
        }
    }
}

pub fn clamp_opacity(value: f64) -> f64 {
    if value.is_nan() { OPACITY_MAX } else { value.clamp(OPACITY_MIN, OPACITY_MAX) }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn opacity_stays_in_range() {
        assert_eq!(clamp_opacity(0.0), OPACITY_MIN);
        assert_eq!(clamp_opacity(2.0), OPACITY_MAX);
        assert_eq!(clamp_opacity(0.6), 0.6);
        assert_eq!(clamp_opacity(f64::NAN), OPACITY_MAX);
    }

    #[test]
    fn round_trips_through_disk() {
        let dir = std::env::temp_dir().join("usage-gauge-test-prefs");
        let prefs = Prefs { opacity: 0.5, panel_visible: false, position: Some((10, -20)) };
        prefs.save(&dir);
        assert_eq!(Prefs::load(&dir), prefs);
        fs::remove_dir_all(&dir).unwrap();
    }
}
