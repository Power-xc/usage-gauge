//! Tray icon: tooltip with the remaining shares, click to toggle, and the menu.

use tauri::menu::{CheckMenuItem, MenuBuilder, MenuEvent, MenuItem, PredefinedMenuItem, SubmenuBuilder};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{AppHandle, Manager};
use tauri_plugin_autostart::ManagerExt;

use crate::app::{refresh, set_layout, set_style, toggle_panel, AppState, TRAY_ID};
use crate::prefs::{PanelLayout, PanelStyle};

const TOGGLE_ID: &str = "toggle";
const REFRESH_ID: &str = "refresh";
const AUTOSTART_ID: &str = "autostart";
const QUIT_ID: &str = "quit";
const STYLE_ID_PREFIX: &str = "style:";
const LAYOUT_ID_PREFIX: &str = "layout:";

pub fn build(app: &AppHandle) -> tauri::Result<()> {
    let autostart = CheckMenuItem::with_id(
        app,
        AUTOSTART_ID,
        "로그인 시 시작",
        true,
        app.autolaunch().is_enabled().unwrap_or(false),
        None::<&str>,
    )?;
    let state = app.state::<AppState>();
    let (current_style, current_layout) = {
        let prefs = state.prefs();
        (prefs.style, prefs.layout)
    };
    let layouts = PanelLayout::ALL
        .into_iter()
        .map(|layout| {
            let id = format!("{LAYOUT_ID_PREFIX}{}", layout.id());
            CheckMenuItem::with_id(app, id, layout.title(), true, layout == current_layout, None::<&str>)
        })
        .collect::<tauri::Result<Vec<_>>>()?;
    let styles = PanelStyle::ALL
        .into_iter()
        .map(|style| {
            let id = format!("{STYLE_ID_PREFIX}{}", style.id());
            CheckMenuItem::with_id(app, id, style.title(), true, style == current_style, None::<&str>)
        })
        .collect::<tauri::Result<Vec<_>>>()?;
    let mut layout_menu = SubmenuBuilder::new(app, "그래프");
    for item in &layouts {
        layout_menu = layout_menu.item(item);
    }
    let mut style_menu = SubmenuBuilder::new(app, "스타일");
    for item in &styles {
        style_menu = style_menu.item(item);
    }
    let menu = MenuBuilder::new(app)
        .item(&MenuItem::with_id(app, TOGGLE_ID, "게이지 켜기/끄기 (Ctrl+Alt+U)", true, None::<&str>)?)
        .item(&MenuItem::with_id(app, REFRESH_ID, "지금 새로고침", true, None::<&str>)?)
        .item(&PredefinedMenuItem::separator(app)?)
        .item(&layout_menu.build()?)
        .item(&style_menu.build()?)
        .item(&autostart)
        .item(&PredefinedMenuItem::separator(app)?)
        .item(&MenuItem::with_id(app, QUIT_ID, "종료", true, None::<&str>)?)
        .build()?;

    let mut tray = TrayIconBuilder::with_id(TRAY_ID)
        .tooltip("UsageGauge")
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(move |app, event| handle_menu(app, &event, &autostart, &layouts, &styles))
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

fn handle_menu(
    app: &AppHandle,
    event: &MenuEvent,
    autostart: &CheckMenuItem<tauri::Wry>,
    layouts: &[CheckMenuItem<tauri::Wry>],
    styles: &[CheckMenuItem<tauri::Wry>],
) {
    let id = event.id().as_ref();
    if let Some(layout) = id.strip_prefix(LAYOUT_ID_PREFIX).and_then(PanelLayout::from_id) {
        choose_layout(app, layout, layouts);
        return;
    }
    if let Some(style) = id.strip_prefix(STYLE_ID_PREFIX).and_then(PanelStyle::from_id) {
        choose_style(app, style, styles);
        return;
    }
    match id {
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

/// Applies the chosen style and leaves exactly its item checked; the menu toggles an item on
/// click by itself, which would otherwise let the one in use be unchecked.
fn choose_style(app: &AppHandle, style: PanelStyle, items: &[CheckMenuItem<tauri::Wry>]) {
    set_style(app, style);
    for (item, candidate) in items.iter().zip(PanelStyle::ALL) {
        if let Err(error) = item.set_checked(candidate == style) {
            eprintln!("usage-gauge: could not update the menu: {error}");
        }
    }
}

/// Same as `choose_style`, for the layout group.
fn choose_layout(app: &AppHandle, layout: PanelLayout, items: &[CheckMenuItem<tauri::Wry>]) {
    set_layout(app, layout);
    for (item, candidate) in items.iter().zip(PanelLayout::ALL) {
        if let Err(error) = item.set_checked(candidate == layout) {
            eprintln!("usage-gauge: could not update the menu: {error}");
        }
    }
}
