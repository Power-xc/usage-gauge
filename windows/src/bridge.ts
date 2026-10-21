import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";
import type { PanelState, UsageView } from "./types";

/** The only place the frontend talks to the backend. It receives computed usage, never tokens. */
export const bridge = {
  state: () => invoke<PanelState>("get_state"),
  setOpacity: (value: number) => invoke("set_opacity", { value }),
  hidePanel: () => invoke("hide_panel"),
  resize: (width: number, height: number) => invoke("resize_panel", { width, height }),
  startDragging: () => getCurrentWindow().startDragging(),
  onUsage: (handler: (usage: UsageView) => void) => listen<UsageView>("usage", (event) => handler(event.payload)),
  onVisibility: (handler: (isShown: boolean) => void) =>
    listen<boolean>("panel-visibility", (event) => handler(event.payload)),
};
