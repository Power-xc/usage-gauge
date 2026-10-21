//! Remembered panel settings, kept as a small JSON file in the app config directory.

use std::fs;
use std::path::Path;

use serde::{Deserialize, Serialize};

pub const OPACITY_MIN: f64 = 0.3;
pub const OPACITY_MAX: f64 = 1.0;
const FILE_NAME: &str = "prefs.json";

/// The panel's look; mirrors the macOS app's `PanelStyle`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum PanelStyle {
    /// Smoked glass with the iris dial.
    #[default]
    Iris,
    /// Matte card with dot-matrix figures.
    Dot,
    /// Black terminal grid with radial ticks.
    Mono,
}

impl PanelStyle {
    pub const ALL: [Self; 3] = [Self::Iris, Self::Dot, Self::Mono];

    pub fn title(self) -> &'static str {
        match self {
            Self::Iris => "홍채 · 글래스",
            Self::Dot => "도트 매트릭스",
            Self::Mono => "모노 터미널",
        }
    }

    pub fn id(self) -> &'static str {
        match self {
            Self::Iris => "iris",
            Self::Dot => "dot",
            Self::Mono => "mono",
        }
    }

    pub fn from_id(id: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|style| style.id() == id)
    }
}

/// Unknown names fall back to iris, so a hand-edited or newer prefs file never breaks loading.
impl<'de> Deserialize<'de> for PanelStyle {
    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let id = String::deserialize(deserializer)?;
        Ok(Self::from_id(&id).unwrap_or_default())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct Prefs {
    pub opacity: f64,
    pub panel_visible: bool,
    /// Top-left of the panel in physical pixels; `None` until the user moves it.
    pub position: Option<(i32, i32)>,
    pub style: PanelStyle,
}

impl Default for Prefs {
    fn default() -> Self {
        Self { opacity: OPACITY_MAX, panel_visible: true, position: None, style: PanelStyle::Iris }
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
        let prefs = Prefs { opacity: 0.5, panel_visible: false, position: Some((10, -20)), style: PanelStyle::Mono };
        prefs.save(&dir);
        assert_eq!(Prefs::load(&dir), prefs);
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn unknown_style_falls_back_to_iris() {
        let prefs: Prefs = serde_json::from_str(r#"{"style":"neon"}"#).unwrap();
        assert_eq!(prefs.style, PanelStyle::Iris);
        let prefs: Prefs = serde_json::from_str(r#"{"style":"dot"}"#).unwrap();
        assert_eq!(prefs.style, PanelStyle::Dot);
        assert_eq!(Prefs::default().style, PanelStyle::Iris);
    }

    #[test]
    fn style_ids_round_trip() {
        for style in PanelStyle::ALL {
            assert_eq!(PanelStyle::from_id(style.id()), Some(style));
        }
    }
}
