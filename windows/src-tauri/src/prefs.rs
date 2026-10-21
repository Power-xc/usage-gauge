//! Remembered panel settings, kept as a small JSON file in the app config directory.

use std::fs;
use std::path::Path;

use serde::{Deserialize, Serialize};

pub const OPACITY_MIN: f64 = 0.3;
pub const OPACITY_MAX: f64 = 1.0;
pub const SCALE_MIN: f64 = 0.7;
pub const SCALE_MAX: f64 = 1.6;
const SCALE_DEFAULT: f64 = 1.0;
const FILE_NAME: &str = "prefs.json";

/// The panel's look; mirrors the macOS app's `PanelStyle`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum PanelStyle {
    /// Black terminal grid with radial ticks.
    #[default]
    Mono,
    /// Smoked glass with the iris dial.
    Iris,
    /// Matte card with dot-matrix figures.
    Dot,
}

impl PanelStyle {
    /// In menu order.
    pub const ALL: [Self; 3] = [Self::Mono, Self::Iris, Self::Dot];

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

/// Unknown names fall back to mono, so a hand-edited or newer prefs file never breaks loading.
impl<'de> Deserialize<'de> for PanelStyle {
    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let id = String::deserialize(deserializer)?;
        Ok(Self::from_id(&id).unwrap_or_default())
    }
}

/// How the panel arranges the tools; mirrors the macOS app's `PanelLayout`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum PanelLayout {
    /// Cards with a dial for the short window and a bar for the long one.
    #[default]
    Dial,
    /// A compact list: both windows of a tool as labelled bars.
    Bars,
    /// A column chart comparing every tool's two windows.
    Columns,
    /// The short-window figure and one line for the long window.
    Figures,
}

impl PanelLayout {
    pub const ALL: [Self; 4] = [Self::Dial, Self::Bars, Self::Columns, Self::Figures];

    pub fn title(self) -> &'static str {
        match self {
            Self::Dial => "다이얼",
            Self::Bars => "바",
            Self::Columns => "막대 그래프",
            Self::Figures => "숫자",
        }
    }

    pub fn id(self) -> &'static str {
        match self {
            Self::Dial => "dial",
            Self::Bars => "bars",
            Self::Columns => "columns",
            Self::Figures => "figures",
        }
    }

    pub fn from_id(id: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|layout| layout.id() == id)
    }
}

/// Unknown names fall back to the dial, for the same reason as `PanelStyle`.
impl<'de> Deserialize<'de> for PanelLayout {
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
    pub layout: PanelLayout,
    /// Panel size factor, `SCALE_MIN...SCALE_MAX`.
    pub scale: f64,
}

impl Default for Prefs {
    fn default() -> Self {
        Self {
            opacity: OPACITY_MAX,
            panel_visible: true,
            position: None,
            style: PanelStyle::default(),
            layout: PanelLayout::default(),
            scale: SCALE_DEFAULT,
        }
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
        prefs.scale = clamp_scale(prefs.scale);
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

pub fn clamp_scale(value: f64) -> f64 {
    if value.is_nan() { SCALE_DEFAULT } else { value.clamp(SCALE_MIN, SCALE_MAX) }
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
        let prefs = Prefs {
            opacity: 0.5,
            panel_visible: false,
            position: Some((10, -20)),
            style: PanelStyle::Dot,
            layout: PanelLayout::Columns,
            scale: 1.25,
        };
        prefs.save(&dir);
        assert_eq!(Prefs::load(&dir), prefs);
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn unknown_style_falls_back_to_mono() {
        let prefs: Prefs = serde_json::from_str(r#"{"style":"neon"}"#).unwrap();
        assert_eq!(prefs.style, PanelStyle::Mono);
        let prefs: Prefs = serde_json::from_str(r#"{"style":"dot"}"#).unwrap();
        assert_eq!(prefs.style, PanelStyle::Dot);
        assert_eq!(Prefs::default().style, PanelStyle::Mono);
    }

    #[test]
    fn unknown_layout_falls_back_to_dial() {
        let prefs: Prefs = serde_json::from_str(r#"{"layout":"orbit"}"#).unwrap();
        assert_eq!(prefs.layout, PanelLayout::Dial);
        let prefs: Prefs = serde_json::from_str(r#"{"layout":"figures"}"#).unwrap();
        assert_eq!(prefs.layout, PanelLayout::Figures);
        assert_eq!(Prefs::default().layout, PanelLayout::Dial);
    }

    #[test]
    fn scale_stays_in_range() {
        assert_eq!(clamp_scale(0.1), SCALE_MIN);
        assert_eq!(clamp_scale(9.0), SCALE_MAX);
        assert_eq!(clamp_scale(1.2), 1.2);
        assert_eq!(clamp_scale(f64::NAN), 1.0);
        assert_eq!(Prefs::default().scale, 1.0);
    }

    #[test]
    fn loading_clamps_a_hand_edited_scale() {
        let dir = std::env::temp_dir().join("usage-gauge-test-scale");
        fs::create_dir_all(&dir).unwrap();
        fs::write(dir.join(FILE_NAME), r#"{"scale":5.0}"#).unwrap();
        assert_eq!(Prefs::load(&dir).scale, SCALE_MAX);
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn style_and_layout_ids_round_trip() {
        for style in PanelStyle::ALL {
            assert_eq!(PanelStyle::from_id(style.id()), Some(style));
        }
        for layout in PanelLayout::ALL {
            assert_eq!(PanelLayout::from_id(layout.id()), Some(layout));
        }
    }
}
