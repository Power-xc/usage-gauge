import type { Drawable } from "./animation";
import { CometBar } from "./comet-bar";
import { DotBar } from "./dot-bar";
import { DotDial } from "./dot-dial";
import { dotMatrixText } from "./dot-matrix";
import { el } from "./dom";
import { IrisDial } from "./iris-dial";
import { TickBar } from "./tick-bar";
import { TickDial } from "./tick-dial";
import { DETAIL_WIDTH, DIAL_SIZE, WHITE, alert, brand, rgba, type Rgb } from "./theme";
import type { PanelStyle, ProviderView, WindowView } from "./types";

export const CARDS_PER_ROW = 2;
const COMET_THICKNESS = 3;
const NO_READING = "–";
/** Dot-matrix figure grid, as a share of the dial; three digits get a finer one to fit the ring. */
const DOT_PITCH = 0.034;
const DOT_PITCH_THREE_DIGITS = 0.026;
const DOT_PERCENT_SCALE = 0.55;
const MUTED_ALPHA = 0.62;

/** The mono and dot styles set type monospaced and count down tersely ("3h 50m"). */
const isMonospaced = (style: PanelStyle): boolean => style !== "iris";

interface Dial extends Drawable {
  canvas: HTMLCanvasElement;
  update(remainingPercent: number, elapsedFraction: number | null, color: Rgb): void;
}

interface Bar extends Drawable {
  canvas: HTMLCanvasElement;
  update(remainingPercent: number, color: Rgb): void;
}

export interface ProviderGrid {
  element: HTMLElement;
  drawables: Drawable[];
}

/**
 * Wide, low grid of provider cards, two per row, set apart by space alone; the mono style sets
 * them in a hairline grid instead (see `style.css`).
 */
export function buildGrid(providers: ProviderView[], style: PanelStyle): ProviderGrid {
  const drawables: Drawable[] = [];
  const grid = el("div", "grid");
  for (let start = 0; start < providers.length; start += CARDS_PER_ROW) {
    const row = el("div", "row");
    providers
      .slice(start, start + CARDS_PER_ROW)
      .forEach((provider, offset) => row.append(buildCard(provider, start + offset, style, drawables)));
    grid.append(row);
  }
  return { element: grid, drawables };
}

/** One provider: the dial on the left, reset time and the long window on the right. */
function buildCard(provider: ProviderView, index: number, style: PanelStyle, drawables: Drawable[]): HTMLElement {
  const tint = brand(provider.id);
  const isConnected = provider.message === null;
  const detail = el("div", "detail", titleRow(provider, index, style, tint));
  if (isConnected) {
    detail.append(
      el("div", "session-line", sessionLine(provider.session, style)),
      longWindow(provider, style, tint, drawables),
    );
  } else {
    detail.append(
      el("div", "offline", "연결 안 됨"),
      el("div", "offline-reason", provider.message ?? ""),
    );
  }
  return el("div", "card", sessionGauge(isConnected ? provider.session : null, style, tint, drawables), detail);
}

/** Iris: the name; dot: its position ("01") before it; mono: a swatch of the tool's colour. */
function titleRow(provider: ProviderView, index: number, style: PanelStyle, tint: Rgb): HTMLElement {
  const row = el("div", "title-row");
  if (style === "dot") row.append(el("span", "index", String(index + 1).padStart(2, "0")));
  if (style === "mono") {
    const swatch = el("span", "swatch");
    swatch.style.background = rgba(tint, 1);
    row.append(swatch);
  }
  row.append(el("span", "name", provider.title));
  if (provider.plan) row.append(el("span", "plan", provider.plan.toUpperCase()));
  return row;
}

/** "5시간 · 3시간 50분 후 초기화" ("3h 50m" in the monospaced styles): which window the dial shows and when it resets. */
function sessionLine(window: WindowView | null, style: PanelStyle): string {
  const countdown = (isMonospaced(style) ? window?.countdownCompact : window?.countdown) ?? NO_READING;
  return `${window?.label ?? "단기"} · ${countdown} 후 초기화`;
}

/** Dial for the style with the remaining percent in the middle; iris also glows through the glass (see `style.css`). */
function sessionGauge(window: WindowView | null, style: PanelStyle, tint: Rgb, drawables: Drawable[]): HTMLElement {
  const dial: Dial = style === "dot" ? new DotDial(DIAL_SIZE) : style === "mono" ? new TickDial(DIAL_SIZE) : new IrisDial(DIAL_SIZE);
  dial.update(window?.remainingPercent ?? 0, window?.elapsedFraction ?? null, tint);
  drawables.push(dial);

  const warning = window ? alert(window.level) : null;
  const value = window ? String(window.displayPercent) : NO_READING;
  const readout = el("div", "pupil-value");
  if (style === "dot") {
    const pitch = DIAL_SIZE * (value.length > 2 ? DOT_PITCH_THREE_DIGITS : DOT_PITCH);
    readout.style.gap = `${pitch}px`;
    readout.append(dotMatrixText(value, pitch, rgba(warning ?? WHITE, 1)));
    if (window) readout.append(dotMatrixText("%", pitch * DOT_PERCENT_SCALE, rgba(WHITE, MUTED_ALPHA)));
  } else {
    const figureColor = warning ?? (style === "mono" ? WHITE : tint);
    const figure = el("span", "figure", value);
    figure.dataset.text = value;
    figure.style.setProperty("--figure-color", rgba(figureColor, 1));
    readout.append(figure);
    if (window) readout.append(el("span", "percent", "%"));
  }
  const element = el("div", "dial", dial.canvas, el("div", "pupil-text", readout));
  element.style.setProperty("--tint", tint.join(" "));
  return element;
}

/** "3일 0시간 후", or the bare "3d 0h" in the monospaced styles. */
function longCountdown(window: WindowView | null, style: PanelStyle): string {
  if (isMonospaced(style)) return window?.countdownCompact ?? NO_READING;
  return `${window?.countdown ?? NO_READING} 후`;
}

/** The long window (weekly, monthly): label, share and reset time over a light-streak bar. */
function longWindow(provider: ProviderView, style: PanelStyle, tint: Rgb, drawables: Drawable[]): HTMLElement {
  const window = provider.weekly;
  const bar: Bar = style === "dot" ? new DotBar(DETAIL_WIDTH) : style === "mono" ? new TickBar(DETAIL_WIDTH) : new CometBar(DETAIL_WIDTH, COMET_THICKNESS);
  bar.update(window?.remainingPercent ?? 0, tint);
  drawables.push(bar);

  const share = el("span", "long-share", window ? `${window.displayPercent}%` : NO_READING);
  const warning = window ? alert(window.level) : null;
  if (warning) share.style.color = rgba(warning, 1);
  const countdown = el("span", "long-countdown", longCountdown(window, style));
  const row = el("div", "long-row", el("span", "long-label", window?.label ?? "장기"), share, countdown);
  return el("div", "long-window", row, bar.canvas);
}
