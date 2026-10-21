import { el } from "../dom";
import { dotMatrixText } from "../dot-matrix";
import { alert, brand, rgba, WHITE } from "../theme";
import type { PanelStyle, ProviderView, WindowView } from "../types";
import { buildGrid, toolColumns } from "./grid";
import { countdown, NO_READING, percentText, providerName } from "./parts";
import type { LayoutContent } from "./types";

const TOOLS_PER_ROW = 4;
const DOT_PITCH = 3.6;
const DOT_PERCENT_SCALE = 0.55;
const MUTED_ALPHA = 0.62;

/** The smallest form: per tool its name, the short window's share in large type and a line for the long window. */
export function buildFiguresLayout(providers: ProviderView[], style: PanelStyle): LayoutContent {
  return buildGrid(providers, style, toolColumns(providers.length, TOOLS_PER_ROW), (provider, index) => buildBlock(provider, index, style));
}

function buildBlock(provider: ProviderView, index: number, style: PanelStyle): HTMLElement {
  const tint = brand(provider.id);
  const name = providerName(provider, index, style, tint, true);
  if (provider.message !== null) {
    return el("div", "figures-block", name, el("div", "big-figure offline", "연결 안 됨"), el("div", "figures-detail faint", provider.message));
  }
  return el("div", "figures-block", name, el("div", "big-figure", ...figure(provider.session, style)), el("div", "figures-detail", detailLine(provider, style)));
}

/** "주간 37% · 3h 50m": the long window's share and when the short one resets. */
function detailLine(provider: ProviderView, style: PanelStyle): string {
  return `${provider.weekly?.label ?? "장기"} ${percentText(provider.weekly)} · ${countdown(provider.session, style)}`;
}

function figure(window: WindowView | null, style: PanelStyle): HTMLElement[] {
  const warning = window ? alert(window.level) : null;
  const text = window ? String(window.displayPercent) : NO_READING;
  if (style === "dot") {
    const parts = [dotMatrixText(text, DOT_PITCH, rgba(warning ?? WHITE, 1))];
    if (window) parts.push(dotMatrixText("%", DOT_PITCH * DOT_PERCENT_SCALE, rgba(WHITE, MUTED_ALPHA)));
    return parts;
  }
  const digits = el("span", "big-digits", text);
  if (warning) digits.style.color = rgba(warning, 1);
  return window ? [digits, el("span", "big-percent", "%")] : [digits];
}
