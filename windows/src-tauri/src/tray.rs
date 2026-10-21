//! Tray icon: tooltip with the remaining shares, click to toggle, and the menu.

use tauri::menu::{CheckMenuItem, MenuBuilder, MenuEvent, MenuItem, PredefinedMenuItem};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::AppHandle;
use tauri_plugin_autostart::ManagerExt;

use crate::app::{refresh, toggle_panel, TRAY_ID};

const TOGGLE_ID: &str = "toggle";
const REFRESH_ID: &str = "refresh";
const AUTOSTART_ID: &str = "autostart";
const QUIT_ID: &str = "quit";

pub fn build(app: &AppHandle) -> tauri::Result<()> {
    let autostart = CheckMenuItem::with_id(
        app,
        AUTOSTART_ID,
        "로그인 시 시작",
        true,
        app.autolaunch().is_enabled().unwrap_or(false),
        None::<&str>,
    )?;
    let menu = MenuBuilder::new(app)
        .item(&MenuItem::with_id(app, TOGGLE_ID, "게이지 켜기/끄기 (Ctrl+Alt+U)", true, None::<&str>)?)
        .item(&MenuItem::with_id(app, REFRESH_ID, "지금 새로고침", true, None::<&str>)?)
        .item(&PredefinedMenuItem::separator(app)?)
        .item(&autostart)
        .item(&PredefinedMenuItem::separator(app)?)
        .item(&MenuItem::with_id(app, QUIT_ID, "종료", true, None::<&str>)?)
        .build()?;

    let mut tray = TrayIconBuilder::with_id(TRAY_ID)
        .tooltip("UsageGauge")
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(move |app, event| handle_menu(app, &event, &autostart))
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click { button: MouseButton::Left, button_state: MouseButtonState::Up, .. } = event {
                toggle_panel(tray.app_handle());
            }
        });
    if let Some(icon) = app.default_window_icon() {
        tray = tray.icon(icon.clone());
    }
    tray.build(app)?;
    Ok(())
}

fn handle_menu(app: &AppHandle, event: &MenuEvent, autostart: &CheckMenuItem<tauri::Wry>) {
    match event.id().as_ref() {
        TOGGLE_ID => toggle_panel(app),
        REFRESH_ID => refresh(app),
        AUTOSTART_ID => toggle_autostart(app, autostart),
        QUIT_ID => app.exit(0),
        _ => {}
    }
}

/// Flips launch-at-login and shows the state that actually took effect.
fn toggle_autostart(app: &AppHandle, item: &CheckMenuItem<tauri::Wry>) {
    let launcher = app.autolaunch();
    let result = if launcher.is_enabled().unwrap_or(false) { launcher.disable() } else { launcher.enable() };
    if let Err(error) = result {
        eprintln!("usage-gauge: could not change launch at login: {error}");
    }
    if let Err(error) = item.set_checked(launcher.is_enabled().unwrap_or(false)) {
        eprintln!("usage-gauge: could not update the menu: {error}");
    }
}
