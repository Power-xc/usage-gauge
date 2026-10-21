import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";
import type { PanelLayout, PanelState, PanelStyle, UsageView } from "./types";

/** The only place the frontend talks to the backend. It receives computed usage, never tokens. */
export const bridge = {
  state: () => invoke<PanelState>("get_state"),
  setOpacity: (value: number) => invoke("set_opacity", { value }),
  setScale: (value: number) => invoke("set_scale", { value }),
  hidePanel: () => invoke("hide_panel"),
  resize: (width: number, height: number) => invoke("resize_panel", { width, height }),
  startDragging: () => getCurrentWindow().startDragging(),
  onUsage: (handler: (usage: UsageView) => void) => listen<UsageView>("usage", (event) => handler(event.payload)),
  onStyle: (handler: (style: PanelStyle) => void) => listen<PanelStyle>("panel-style", (event) => handler(event.payload)),
  onLayout: (handler: (layout: PanelLayout) => void) =>
    listen<PanelLayout>("panel-layout", (event) => handler(event.payload)),
  onVisibility: (handler: (isShown: boolean) => void) =>
    listen<boolean>("panel-visibility", (event) => handler(event.payload)),
};
