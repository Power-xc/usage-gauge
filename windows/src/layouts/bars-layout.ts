import type { Drawable } from "../animation";
import { el } from "../dom";
import { alert, brand, rgba, type Rgb } from "../theme";
import type { PanelStyle, ProviderView, WindowView } from "../types";
import { revealingCaption } from "../reveal";
import { buildGrid } from "./grid";
import { countdown, percentText, planTag, providerName, windowBar } from "./parts";
import type { LayoutContent } from "./types";

const NAME_WIDTH = 120;
const BLOCK_GAP = 12;
const ROW_GAP = 8;
const LABEL_WIDTH = 38;
const FIGURE_WIDTH = 36;
const COUNTDOWN_WIDTH = 56;

/** A compact list: the tool's name on the left, a row per window to its right with label, bar, share and reset time. */
export function buildBarsLayout(providers: ProviderView[], style: PanelStyle): LayoutContent {
  return buildGrid(providers, style, 1, (provider, index, width, drawables) => buildBlock(provider, index, width, style, drawables));
}

function buildBlock(provider: ProviderView, index: number, width: number, style: PanelStyle, drawables: Drawable[]): HTMLElement {
  const tint = brand(provider.id);
  const name = el("div", "bars-name", providerName(provider, index, style, tint), revealingCaption(provider, planTag(provider)[0] ?? null, { isCompact: true }));
  const block = el("div", "bars-block", name);
  if (provider.message === null) {
    const barWidth = width - NAME_WIDTH - BLOCK_GAP - LABEL_WIDTH - FIGURE_WIDTH - COUNTDOWN_WIDTH - 3 * ROW_GAP;
    block.append(
      el(
        "div",
        "bars-rows",
        barRow(provider.session, "단기", barWidth, style, tint, drawables),
        barRow(provider.weekly, "장기", barWidth, style, tint, drawables),
      ),
    );
  } else {
    block.append(el("span", "offline", "연결 안 됨"));
  }
  return block;
}

/** Label, bar, share and countdown of one window, on a single line. */
function barRow(window: WindowView | null, fallbackLabel: string, barWidth: number, style: PanelStyle, tint: Rgb, drawables: Drawable[]): HTMLElement {
  const label = el("span", "bar-label", window?.label ?? fallbackLabel);
  const share = el("span", "bar-share", percentText(window));
  const warning = window ? alert(window.level) : null;
  if (warning) share.style.color = rgba(warning, 1);
  return el(
    "div",
    "bar-row",
    label,
    windowBar(style, barWidth, window?.remainingPercent ?? 0, tint, drawables),
    share,
    el("span", "bar-countdown", countdown(window, style)),
  );
}
