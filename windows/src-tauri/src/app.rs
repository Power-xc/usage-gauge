//! Shared application state and the actions the tray, shortcut, scheduler and webview all use.

use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Mutex, MutexGuard, PoisonError};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use tauri::{AppHandle, Emitter, Manager, WebviewWindow};

use crate::history::UsageHistory;
use crate::prefs::{PanelLayout, PanelStyle, Prefs};
use crate::providers;
use crate::store::Store;
use crate::view::{tooltip, usage_view};

pub const MAIN_WINDOW: &str = "main";
pub const TRAY_ID: &str = "main";
const TICK_INTERVAL: Duration = Duration::from_secs(15);
const SAVE_DELAY: Duration = Duration::from_millis(400);

pub struct AppState {
    store: Mutex<Store>,
    prefs: Mutex<Prefs>,
    config_dir: PathBuf,
    data_dir: PathBuf,
    has_glass: AtomicBool,
    is_revealed: AtomicBool,
    save_generation: AtomicU64,
}

impl AppState {
    pub fn new(config_dir: PathBuf, data_dir: PathBuf) -> Self {
        Self {
            store: Mutex::new(Store::with_history(UsageHistory::load(&data_dir, unix_now()))),
            prefs: Mutex::new(Prefs::load(&config_dir)),
            config_dir,
            data_dir,
            has_glass: AtomicBool::new(false),
            is_revealed: AtomicBool::new(false),
            save_generation: AtomicU64::new(0),
        }
    }

    pub fn store(&self) -> MutexGuard<'_, Store> {
        self.store.lock().unwrap_or_else(PoisonError::into_inner)
    }

    pub fn prefs(&self) -> MutexGuard<'_, Prefs> {
        self.prefs.lock().unwrap_or_else(PoisonError::into_inner)
    }

    pub fn has_glass(&self) -> bool {
        self.has_glass.load(Ordering::Relaxed)
    }

    pub fn set_has_glass(&self, value: bool) {
        self.has_glass.store(value, Ordering::Relaxed);
    }

    /// `true` only the first time, so the panel is revealed once its content has been sized.
    pub fn take_first_reveal(&self) -> bool {
        !self.is_revealed.swap(true, Ordering::Relaxed)
    }

    /// Writes the settings shortly after the last change, so dragging a slider or the window
    /// does not hit the disk on every event.
    pub fn save_prefs_soon(app: &AppHandle) {
        let state = app.state::<AppState>();
        let generation = state.save_generation.fetch_add(1, Ordering::SeqCst) + 1;
        let app = app.clone();
        thread::spawn(move || {
            thread::sleep(SAVE_DELAY);
            let state = app.state::<AppState>();
            if state.save_generation.load(Ordering::SeqCst) == generation {
                state.save_prefs_now();
            }
        });
    }

    pub fn save_prefs_now(&self) {
        self.prefs().save(&self.config_dir);
    }
}

pub fn unix_now() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |elapsed| elapsed.as_secs() as i64)
}

pub fn main_window(app: &AppHandle) -> Option<WebviewWindow> {
    app.get_webview_window(MAIN_WINDOW)
}

/// Fetches fresh numbers off the calling thread; ignored while a fetch is already running.
pub fn refresh(app: &AppHandle) {
    let state = app.state::<AppState>();
    let started = unix_now();
    if !state.store().begin_fetch(started) {
        return;
    }
    let app = app.clone();
    thread::spawn(move || {
        let latest = providers::fetch_all(started);
        let state = app.state::<AppState>();
        let history = {
            let mut store = state.store();
            store.finish_fetch(latest, unix_now());
            store.history().clone()
        };
        history.save(&state.data_dir);
        publish(&app);
    });
}

/// Refreshes unless the data is already fresh.
pub fn refresh_if_stale(app: &AppHandle) {
    if app.state::<AppState>().store().is_stale(unix_now()) {
        refresh(app);
    }
}

/// Sends the current readings to the webview and the tray tooltip.
pub fn publish(app: &AppHandle) {
    let view = usage_view(&app.state::<AppState>().store());
    if let Some(tray) = app.tray_by_id(TRAY_ID) {
        if let Err(error) = tray.set_tooltip(Some(tooltip(&view))) {
            eprintln!("usage-gauge: could not update the tray tooltip: {error}");
        }
    }
    if let Err(error) = app.emit("usage", view) {
        eprintln!("usage-gauge: could not publish usage: {error}");
    }
}

/// Remembers the chosen style and restyles the open panel.
pub fn set_style(app: &AppHandle, style: PanelStyle) {
    app.state::<AppState>().prefs().style = style;
    AppState::save_prefs_soon(app);
    if let Err(error) = app.emit("panel-style", style) {
        eprintln!("usage-gauge: could not announce the panel style: {error}");
    }
}

/// Remembers the chosen layout and rearranges the open panel.
pub fn set_layout(app: &AppHandle, layout: PanelLayout) {
    app.state::<AppState>().prefs().layout = layout;
    AppState::save_prefs_soon(app);
    if let Err(error) = app.emit("panel-layout", layout) {
        eprintln!("usage-gauge: could not announce the panel layout: {error}");
    }
}

pub fn toggle_panel(app: &AppHandle) {
    let Some(window) = main_window(app) else { return };
    let show = !window.is_visible().unwrap_or(false);
    set_panel_shown(app, show);
    if show {
        refresh_if_stale(app);
    }
}

pub fn set_panel_shown(app: &AppHandle, show: bool) {
    let Some(window) = main_window(app) else { return };
    let result = if show { window.show() } else { window.hide() };
    if let Err(error) = result {
        eprintln!("usage-gauge: could not change panel visibility: {error}");
        return;
    }
    app.state::<AppState>().prefs().panel_visible = show;
    AppState::save_prefs_soon(app);
    if let Err(error) = app.emit("panel-visibility", show) {
        eprintln!("usage-gauge: could not announce panel visibility: {error}");
    }
}

/// Keeps countdowns current and fetches on the periodic, reset and resume rules in `Store::tick`.
pub fn start_scheduler(app: &AppHandle) {
    let app = app.clone();
    thread::spawn(move || loop {
        thread::sleep(TICK_INTERVAL);
        let is_due = app.state::<AppState>().store().tick(unix_now());
        publish(&app);
        if is_due {
            refresh(&app);
        }
    });
}
