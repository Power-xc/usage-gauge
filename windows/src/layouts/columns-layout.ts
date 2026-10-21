import { el } from "../dom";
import { alert, brand, rgba, type Rgb } from "../theme";
import type { PanelStyle, ProviderView, WindowView } from "../types";
import { verticalMeter } from "../vertical-meter";
import { buildGrid, toolColumns } from "./grid";
import { countdown, percentText, providerName } from "./parts";
import type { LayoutContent } from "./types";

const TOOLS_PER_ROW = 4;
const COLUMN_WIDTH = 22;
const COLUMN_HEIGHT = 84;

/** A column chart comparing the tools: per tool a column for each window, as tall as what is left. */
export function buildColumnsLayout(providers: ProviderView[], style: PanelStyle): LayoutContent {
  return buildGrid(providers, style, toolColumns(providers.length, TOOLS_PER_ROW), (provider, index) => buildBlock(provider, index, style));
}

function buildBlock(provider: ProviderView, index: number, style: PanelStyle): HTMLElement {
  const tint = brand(provider.id);
  const isConnected = provider.message === null;
  const caption = isConnected ? el("span", "caption", countdown(provider.session, style)) : el("span", "caption muted", "연결 안 됨");
  const block = el(
    "div",
    "columns-block",
    el("div", "columns", column(provider.session, "단", style, tint), column(provider.weekly, "장", style, tint)),
    el("div", "columns-name", providerName(provider, index, style, tint, true), caption),
  );
  block.classList.toggle("unavailable", !isConnected);
  return block;
}

function column(window: WindowView | null, fallbackLabel: string, style: PanelStyle, tint: Rgb): HTMLElement {
  const figure = el("span", "column-figure", percentText(window));
  const warning = window ? alert(window.level) : null;
  if (warning) figure.style.color = rgba(warning, 1);
  const meter = verticalMeter(style, window?.remainingPercent ?? 0, tint, COLUMN_WIDTH, COLUMN_HEIGHT);
  return el("div", "column", figure, meter, el("span", "column-label", shortLabel(window?.label) ?? fallbackLabel));
}

/** "5h", "주", "월", … — the window's name in a few characters. */
function shortLabel(label: string | undefined): string | null {
  if (!label) return null;
  return label.endsWith("시간") ? `${label.slice(0, -2)}h` : label.slice(0, 1);
}
