import type { Drawable } from "./animation";
import { CometBar } from "./comet-bar";
import { el } from "./dom";
import { IrisDial } from "./iris-dial";
import { DETAIL_WIDTH, DIAL_SIZE, alert, brand, rgba, type Rgb } from "./theme";
import type { ProviderView, WindowView } from "./types";

export const CARDS_PER_ROW = 2;
const COMET_THICKNESS = 3;
const NO_READING = "–";

export interface ProviderGrid {
  element: HTMLElement;
  drawables: Drawable[];
}

/** Wide, low grid of provider cards, two per row, set apart by space alone. */
export function buildGrid(providers: ProviderView[]): ProviderGrid {
  const drawables: Drawable[] = [];
  const grid = el("div", "grid");
  for (let start = 0; start < providers.length; start += CARDS_PER_ROW) {
    const row = el("div", "row");
    providers.slice(start, start + CARDS_PER_ROW).forEach((provider) => row.append(buildCard(provider, drawables)));
    grid.append(row);
  }
  return { element: grid, drawables };
}

/** One provider: the dial on the left, reset time and the long window on the right. */
function buildCard(provider: ProviderView, drawables: Drawable[]): HTMLElement {
  const tint = brand(provider.id);
  const isConnected = provider.message === null;
  const detail = el("div", "detail", titleRow(provider));
  if (isConnected) {
    detail.append(el("div", "session-line", sessionLine(provider.session)), longWindow(provider, tint, drawables));
  } else {
    detail.append(
      el("div", "offline", "연결 안 됨"),
      el("div", "offline-reason", provider.message ?? ""),
    );
  }
  return el("div", "card", sessionGauge(isConnected ? provider.session : null, tint, drawables), detail);
}

function titleRow(provider: ProviderView): HTMLElement {
  const row = el("div", "title-row", el("span", "name", provider.title));
  if (provider.plan) row.append(el("span", "plan", provider.plan.toUpperCase()));
  return row;
}

/** "5시간 · 3시간 50분 후 초기화": which window the dial shows and when it resets. */
function sessionLine(window: WindowView | null): string {
  return `${window?.label ?? "단기"} · ${window?.countdown ?? NO_READING} 후 초기화`;
}

/**
 * Iris dial with the remaining percent in the pupil, lit from below by the tool's colour, which
 * also glows through the glass behind the dial.
 */
function sessionGauge(window: WindowView | null, tint: Rgb, drawables: Drawable[]): HTMLElement {
  const dial = new IrisDial(DIAL_SIZE);
  dial.update(window?.remainingPercent ?? 0, window?.elapsedFraction ?? null, tint);
  drawables.push(dial);

  const figureColor = window ? (alert(window.level) ?? tint) : tint;
  const value = window ? String(window.displayPercent) : NO_READING;
  const figure = el("span", "figure", value);
  figure.dataset.text = value;
  figure.style.setProperty("--figure-color", rgba(figureColor, 1));
  const readout = el("div", "pupil-value", figure);
  if (window) readout.append(el("span", "percent", "%"));
  const element = el("div", "dial", dial.canvas, el("div", "pupil-text", readout));
  element.style.setProperty("--tint", tint.join(" "));
  return element;
}

/** The long window (weekly, monthly): label, share and reset time over a light-streak bar. */
function longWindow(provider: ProviderView, tint: Rgb, drawables: Drawable[]): HTMLElement {
  const window = provider.weekly;
  const bar = new CometBar(DETAIL_WIDTH, COMET_THICKNESS);
  bar.update(window?.remainingPercent ?? 0, tint);
  drawables.push(bar);

  const share = el("span", "long-share", window ? `${window.displayPercent}%` : NO_READING);
  const warning = window ? alert(window.level) : null;
  if (warning) share.style.color = rgba(warning, 1);
  const countdown = el("span", "long-countdown", `${window?.countdown ?? NO_READING} 후`);
  const row = el("div", "long-row", el("span", "long-label", window?.label ?? "장기"), share, countdown);
  return el("div", "long-window", row, bar.canvas);
}
