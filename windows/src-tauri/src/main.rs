// Keeps a console window from opening alongside the panel in release builds on Windows.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    usage_gauge_lib::run()
}
