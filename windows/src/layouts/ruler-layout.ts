import { el } from "../dom";
import { percentFigure } from "../figure";
import { FIGURE_X, rulerTrack, shareY } from "../ruler-track";
import { brand } from "../theme";
import type { PanelStyle, ProviderView, WindowView } from "../types";
import { buildGrid, toolColumns } from "./grid";
import { countdown, providerName } from "./parts";
import type { LayoutContent } from "./types";

const TOOLS_PER_ROW = 4;
const RULER_HEIGHT = 190;
/** A ruler never grows wider than this; in a wider cell it is centred. */
const MAX_WIDTH = 148;
const FIGURE_MIN = 20;
const FIGURE_MAX = 34;
/** Width of the share's figure in ems of its size, plus the room kept right of it. */
const FIGURE_WIDTH_EMS = 2.3;
const FIGURE_RIGHT_MARGIN = 6;
const FIGURE_GAP = 4;

/**
 * A vertical ruler per tool, side by side: the short window's share runs up it as a line that
 * bulges around a knob, with the share in large type beside the knob, the long window as a notch
 * on the other side, and the name and countdown underneath.
 */
export function buildRulerLayout(providers: ProviderView[], style: PanelStyle): LayoutContent {
  return buildGrid(providers, style, toolColumns(providers.length, TOOLS_PER_ROW), (provider, index, width) =>
    buildBlock(provider, index, width, style),
  );
}

function buildBlock(provider: ProviderView, index: number, width: number, style: PanelStyle): HTMLElement {
  const tint = brand(provider.id);
  const isConnected = provider.message === null;
  const content = Math.min(width, MAX_WIDTH);
  const track = rulerTrack(
    style,
    {
      tint,
      notchLabel: isConnected && provider.weekly ? notchLabel(provider.weekly) : null,
      isActive: provider.session !== null,
      remaining: provider.session?.remainingPercent ?? 0,
      longRemaining: provider.weekly?.remainingPercent ?? 0,
    },
    content,
    RULER_HEIGHT,
  );
  const ruler = el("div", "ruler", track, ...readout(provider, content, style));
  ruler.style.width = `${content}px`;
  ruler.style.height = `${RULER_HEIGHT}px`;
  const name = el("div", "ruler-name", providerName(provider, index, style, tint, true), el("span", "caption", caption(provider, style)));
  const block = el("div", "ruler-block", ruler, name);
  block.style.width = `${content}px`;
  block.classList.toggle("unavailable", !isConnected);
  return block;
}

/** The share beside the knob, as tall as the ruler's end padding so it fits at 0 and at 100. */
function readout(provider: ProviderView, content: number, style: PanelStyle): HTMLElement[] {
  if (provider.session) {
    const size = Math.min(FIGURE_MAX, Math.max(FIGURE_MIN, (content - FIGURE_X - FIGURE_RIGHT_MARGIN) / FIGURE_WIDTH_EMS));
    const figure = percentFigure(provider.session, size, style);
    figure.classList.add("ruler-readout");
    figure.style.left = `${FIGURE_X + FIGURE_GAP}px`;
    figure.style.top = `${shareY(provider.session.remainingPercent, RULER_HEIGHT) - size / 2}px`;
    return [figure];
  }
  if (provider.message !== null) {
    const offline = el("span", "ruler-readout ruler-offline", "연결 안 됨");
    offline.style.left = `${FIGURE_X}px`;
    offline.style.top = `${RULER_HEIGHT / 2}px`;
    return [offline];
  }
  return [];
}

/** "3h 50m · 주 37%": when the short window resets, then the long window's share. */
function caption(provider: ProviderView, style: PanelStyle): string {
  if (provider.message !== null) return provider.message;
  const reset = countdown(provider.session ?? provider.weekly, style);
  return provider.weekly ? `${reset} · ${notchLabel(provider.weekly)} ${provider.weekly.displayPercent}%` : reset;
}

/** One syllable for the long window: 주 (weekly), 월 (monthly), 일 (daily). */
function notchLabel(window: WindowView): string {
  switch (window.label) {
    case "월간":
      return "월";
    case "일간":
      return "일";
    default:
      return "주";
  }
}
