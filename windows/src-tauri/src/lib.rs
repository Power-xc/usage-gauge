mod app;
mod credentials;
mod history;
mod history_view;
mod http;
mod model;
mod panel;
mod prefs;
mod providers;
mod store;
mod tray;
mod view;

use tauri::{Manager, RunEvent};
use tauri_plugin_autostart::MacosLauncher;
use tauri_plugin_global_shortcut::{Code, GlobalShortcutExt, Modifiers, Shortcut, ShortcutState};

use app::{main_window, refresh, start_scheduler, toggle_panel, AppState};

pub fn run() {
    let toggle_shortcut = Shortcut::new(Some(Modifiers::CONTROL | Modifiers::ALT), Code::KeyU);
    let app = tauri::Builder::default()
        .plugin(tauri_plugin_autostart::init(MacosLauncher::LaunchAgent, None))
        .plugin(
            tauri_plugin_global_shortcut::Builder::new()
                .with_handler(move |app, shortcut, event| {
                    if *shortcut == toggle_shortcut && event.state() == ShortcutState::Pressed {
                        toggle_panel(app);
                    }
                })
                .build(),
        )
        .invoke_handler(tauri::generate_handler![
            panel::get_state,
            panel::set_opacity,
            panel::set_scale,
            panel::hide_panel,
            panel::resize_panel
        ])
        .setup(move |app| {
            let handle = app.handle().clone();
            app.manage(AppState::new(app.path().app_config_dir()?, app.path().app_data_dir()?));
            let window = main_window(&handle).ok_or("main window is missing")?;
            let state = handle.state::<AppState>();
            state.set_has_glass(panel::apply_glass(&window));
            panel::restore_position(&window, state.prefs().position);
            panel::track_position(&window, handle.clone());
            tray::build(&handle)?;
            app.global_shortcut().register(toggle_shortcut)?;
            refresh(&handle);
            start_scheduler(&handle);
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("failed to build UsageGauge");

    app.run(|handle, event| {
        if let RunEvent::Exit = event {
            handle.state::<AppState>().save_prefs_now();
        }
    });
}
