import type { Drawable } from "../animation";
import { hoverLine } from "../clock";
import { el } from "../dom";
import { percentFigure } from "../figure";
import { innerRadius, orbitRings, type OrbitRing } from "../orbit-rings";
import { alert, brand, rgba } from "../theme";
import type { PanelStyle, ProviderView, WindowView } from "../types";
import { singleCell } from "./grid";
import { countdown, percentText } from "./parts";
import type { LayoutContent } from "./types";

const CHART_SIZE = 150;
const MAX_RINGS = 6;
const CENTRE_FIGURE_SIZE = 24;
/** The figure sits inside the free middle, a little short of its edge. */
const CENTRE_MARGIN = 6;

/**
 * One chart for every tool: concentric rings (the first tool outermost) lit for the short
 * window's remaining share, the lowest of them in the middle, and a legend with both windows and
 * the reset countdown per tool. A tool is one ring and one legend row: pointing at either focuses
 * it (the middle then shows its share and the legend its times) and clicking opens it.
 */
export function buildOrbitLayout(providers: ProviderView[], style: PanelStyle): LayoutContent {
  const drawables: Drawable[] = [];
  const orbit = el("div", "orbit", chart(providers, style, drawables), legend(providers, style));
  return { element: singleCell(orbit, style).element, drawables };
}

function chart(providers: ProviderView[], style: PanelStyle, drawables: Drawable[]): HTMLElement {
  const ringed = providers.slice(0, MAX_RINGS);
  const rings: OrbitRing[] = ringed.map((provider) => ({
    id: provider.id,
    remainingPercent: provider.message === null ? (provider.session?.remainingPercent ?? null) : null,
    tint: brand(provider.id),
  }));
  const width = `${innerRadius(rings.length, CHART_SIZE) * 2 - CENTRE_MARGIN}px`;
  const lowestTool = lowest(providers);
  const middles = [
    centre(lowestTool, lowestTool ? `최저 · ${lowestTool.title}` : "연결 안 됨", style, width, "lowest"),
    ...ringed.map((provider) => {
      const middle = centre(provider, provider.title, style, width, "of-tool");
      middle.dataset.follows = provider.id;
      return middle;
    }),
  ];
  const element = el("div", "orbit-chart", orbitRings(style, rings, CHART_SIZE, drawables), ...middles);
  element.style.width = element.style.height = `${CHART_SIZE}px`;
  return element;
}

/** The share in the middle and whose it is: the focused tool's, else the lowest. */
function centre(provider: ProviderView | null, label: string, style: PanelStyle, width: string, kind: string): HTMLElement {
  const middle = el("div", `orbit-centre ${kind}`, percentFigure(provider?.session ?? null, CENTRE_FIGURE_SIZE, style), el("span", "orbit-centre-label", label));
  middle.style.width = width;
  return middle;
}

/** The tool with the least left in its short window. */
function lowest(providers: ProviderView[]): ProviderView | null {
  let best: ProviderView | null = null;
  for (const provider of providers) {
    if (provider.message !== null || !provider.session) continue;
    if (!best || provider.session.remainingPercent < (best.session?.remainingPercent ?? 0)) best = provider;
  }
  return best;
}

/** One row per tool in aligned columns: name, short window, long window and the short window's countdown. */
function legend(providers: ProviderView[], style: PanelStyle): HTMLElement {
  const heading = el("div", "orbit-row orbit-heading", el("span", "orbit-spacer"), cell("단기", "short"), cell("장기", "long"), cell("초기화", "countdown"));
  return el("div", "orbit-legend", heading, ...providers.map((provider) => row(provider, style)), revealedTimes(providers));
}

/** The focused tool's reset and measuring times, in a line the legend always keeps free. */
function revealedTimes(providers: ProviderView[]): HTMLElement {
  const times = providers.filter((provider) => provider.message === null).map((provider) => {
    const line = el("span", "orbit-time", hoverLine(provider));
    line.dataset.follows = provider.id;
    return line;
  });
  return el("div", "orbit-row orbit-times", ...times);
}

function cell(text: string, kind: string, color?: string): HTMLElement {
  const node = el("span", `orbit-cell ${kind}`, text);
  if (color) node.style.color = color;
  return node;
}

function row(provider: ProviderView, style: PanelStyle): HTMLElement {
  const bullet = el("span", style === "mono" ? "orbit-bullet square" : "orbit-bullet");
  bullet.style.background = rgba(brand(provider.id), 1);
  const name = el("span", "orbit-name", provider.title);
  const label = el("span", "orbit-label", bullet, name);
  const line = (...cells: HTMLElement[]): HTMLElement => {
    const node = el("div", "orbit-row", ...cells);
    node.dataset.tool = provider.id;
    return node;
  };
  if (provider.message !== null) return line(label, el("span", "orbit-spacer"), el("span", "orbit-offline", "연결 안 됨"));
  return line(
    label,
    el("span", "orbit-spacer"),
    cell(percentText(provider.session), "short", warning(provider.session)),
    cell(percentText(provider.weekly), "long", warning(provider.weekly)),
    cell(countdown(provider.session, style), "countdown"),
  );
}

function warning(window: WindowView | null): string | undefined {
  const color = window ? alert(window.level) : null;
  return color ? rgba(color, 1) : undefined;
}
