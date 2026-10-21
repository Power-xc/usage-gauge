//! The floating panel window: glass, size, placement and the commands the webview calls.

use serde::Serialize;
use tauri::{AppHandle, LogicalSize, Manager, PhysicalPosition, State, WebviewWindow, WindowEvent};

use crate::app::{main_window, publish, set_panel_shown, AppState};
use crate::prefs::{clamp_opacity, clamp_scale, PanelLayout, PanelStyle};
use crate::view::{usage_view, UsageView};

/// Smoke tint the acrylic sits under is drawn by the page; the acrylic itself stays untinted.
#[cfg(windows)]
const ACRYLIC_TINT: (u8, u8, u8, u8) = (9, 10, 15, 0);

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PanelState {
    usage: UsageView,
    opacity: f64,
    is_shown: bool,
    has_glass: bool,
    style: PanelStyle,
    layout: PanelLayout,
    scale: f64,
}

/// Applies Windows acrylic; elsewhere, or when it fails, the page falls back to a denser smoke.
pub fn apply_glass(window: &WebviewWindow) -> bool {
    #[cfg(windows)]
    {
        match window_vibrancy::apply_acrylic(window, Some(ACRYLIC_TINT)) {
            Ok(()) => return true,
            Err(error) => eprintln!("usage-gauge: acrylic unavailable: {error}"),
        }
    }
    #[cfg(not(windows))]
    let _ = window;
    false
}

/// Puts the panel back where the user left it, if that spot is still on a screen.
pub fn restore_position(window: &WebviewWindow, saved: Option<(i32, i32)>) {
    let Some((x, y)) = saved else {
        if let Err(error) = window.center() {
            eprintln!("usage-gauge: could not centre the panel: {error}");
        }
        return;
    };
    let is_on_screen = window.available_monitors().unwrap_or_default().iter().any(|monitor| {
        let (origin, size) = (monitor.position(), monitor.size());
        x >= origin.x && y >= origin.y && x < origin.x + size.width as i32 && y < origin.y + size.height as i32
    });
    if is_on_screen {
        if let Err(error) = window.set_position(PhysicalPosition::new(x, y)) {
            eprintln!("usage-gauge: could not restore the panel position: {error}");
        }
    }
}

/// Remembers where the panel is dragged to.
pub fn track_position(window: &WebviewWindow, app: AppHandle) {
    window.on_window_event(move |event| {
        if let WindowEvent::Moved(position) = event {
            app.state::<AppState>().prefs().position = Some((position.x, position.y));
            AppState::save_prefs_soon(&app);
        }
    });
}

#[tauri::command]
pub fn get_state(app: AppHandle, state: State<AppState>) -> PanelState {
    PanelState {
        usage: usage_view(&state.store()),
        opacity: state.prefs().opacity,
        is_shown: main_window(&app).and_then(|window| window.is_visible().ok()).unwrap_or(false),
        has_glass: state.has_glass(),
        style: state.prefs().style,
        layout: state.prefs().layout,
        scale: state.prefs().scale,
    }
}

#[tauri::command]
pub fn set_opacity(app: AppHandle, state: State<AppState>, value: f64) {
    state.prefs().opacity = clamp_opacity(value);
    AppState::save_prefs_soon(&app);
}

/// Persists the size chosen with the bar; the webview scales itself and resizes the window.
#[tauri::command]
pub fn set_scale(app: AppHandle, state: State<AppState>, value: f64) {
    state.prefs().scale = clamp_scale(value);
    AppState::save_prefs_soon(&app);
}

#[tauri::command]
pub fn hide_panel(app: AppHandle) {
    set_panel_shown(&app, false);
}

/// Moves a window that grew past the edge of its monitor back inside it.
fn keep_on_screen(window: &WebviewWindow, width: f64, height: f64) {
    let (Ok(Some(monitor)), Ok(position)) = (window.current_monitor(), window.outer_position()) else { return };
    let factor = window.scale_factor().unwrap_or(1.0);
    let size = ((width * factor).round() as i32, (height * factor).round() as i32);
    let (origin, area) = (monitor.position(), monitor.size());
    let fitted = fit_within((origin.x, origin.y), (area.width as i32, area.height as i32), (position.x, position.y), size);
    if fitted != (position.x, position.y) {
        if let Err(error) = window.set_position(PhysicalPosition::new(fitted.0, fitted.1)) {
            eprintln!("usage-gauge: could not keep the panel on screen: {error}");
        }
    }
}

/// Top-left that puts a `size` box at `position` inside the area, preferring the top-left corner
/// when the box is larger than the area.
fn fit_within(origin: (i32, i32), area: (i32, i32), position: (i32, i32), size: (i32, i32)) -> (i32, i32) {
    let x = position.0.min(origin.0 + area.0 - size.0).max(origin.0);
    let y = position.1.min(origin.1 + area.1 - size.1).max(origin.1);
    (x, y)
}

/// The window follows its content. The first call also reveals the panel, so it never shows
/// at a placeholder size.
#[tauri::command]
pub fn resize_panel(app: AppHandle, state: State<AppState>, width: f64, height: f64) {
    let Some(window) = main_window(&app) else { return };
    if let Err(error) = window.set_size(LogicalSize::new(width, height)) {
        eprintln!("usage-gauge: could not resize the panel: {error}");
    }
    keep_on_screen(&window, width, height);
    if state.take_first_reveal() {
        let wanted = state.prefs().panel_visible;
        if wanted {
            set_panel_shown(&app, true);
        }
        publish(&app);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn growing_panel_is_pulled_back_inside_the_monitor() {
        assert_eq!(fit_within((0, 0), (1920, 1080), (1700, 900), (500, 300)), (1420, 780));
        assert_eq!(fit_within((0, 0), (1920, 1080), (100, 100), (500, 300)), (100, 100));
        assert_eq!(fit_within((-1920, 0), (1920, 1080), (-10, 0), (500, 300)), (-500, 0));
        assert_eq!(fit_within((0, 0), (400, 200), (50, 50), (500, 300)), (0, 0));
    }
}
