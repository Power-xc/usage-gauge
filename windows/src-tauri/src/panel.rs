//! The floating panel window: glass, size, placement and the commands the webview calls.

use serde::Serialize;
use tauri::{AppHandle, LogicalSize, Manager, PhysicalPosition, State, WebviewWindow, WindowEvent};

use crate::app::{main_window, publish, set_panel_shown, AppState};
use crate::prefs::{clamp_opacity, PanelStyle};
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
    }
}

#[tauri::command]
pub fn set_opacity(app: AppHandle, state: State<AppState>, value: f64) {
    state.prefs().opacity = clamp_opacity(value);
    AppState::save_prefs_soon(&app);
}

#[tauri::command]
pub fn hide_panel(app: AppHandle) {
    set_panel_shown(&app, false);
}

/// The window follows its content. The first call also reveals the panel, so it never shows
/// at a placeholder size.
#[tauri::command]
pub fn resize_panel(app: AppHandle, state: State<AppState>, width: f64, height: f64) {
    let Some(window) = main_window(&app) else { return };
    if let Err(error) = window.set_size(LogicalSize::new(width, height)) {
        eprintln!("usage-gauge: could not resize the panel: {error}");
    }
    if state.take_first_reveal() {
        let wanted = state.prefs().panel_visible;
        if wanted {
            set_panel_shown(&app, true);
        }
        publish(&app);
    }
}
