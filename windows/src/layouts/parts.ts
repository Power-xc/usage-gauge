import type { Drawable } from "../animation";
import { CometBar } from "../comet-bar";
import { DotBar } from "../dot-bar";
import { DotDial } from "../dot-dial";
import { dotMatrixText } from "../dot-matrix";
import { el } from "../dom";
import { IrisDial } from "../iris-dial";
import { TickBar } from "../tick-bar";
import { TickDial } from "../tick-dial";
import { DETAIL_WIDTH, DIAL_SIZE, WHITE, alert, rgba, type Rgb } from "../theme";
import type { PanelStyle, ProviderView, WindowView } from "../types";

export const NO_READING = "–";
const COMET_THICKNESS = 3;
/** Dot-matrix figure grid, as a share of the dial; three digits get a finer one to fit the ring. */
const DOT_PITCH = 0.034;
const DOT_PITCH_THREE_DIGITS = 0.026;
const DOT_PERCENT_SCALE = 0.55;
const MUTED_ALPHA = 0.62;

/** The mono and dot styles set type monospaced and count down tersely ("3h 50m"). */
export const isMonospaced = (style: PanelStyle): boolean => style !== "iris";

interface Dial extends Drawable {
  canvas: HTMLCanvasElement;
  update(remainingPercent: number, elapsedFraction: number | null, color: Rgb): void;
}

interface Bar extends Drawable {
  canvas: HTMLCanvasElement;
  update(remainingPercent: number, color: Rgb): void;
}

/** "37%", or a dash for a window the tool does not report. */
export const percentText = (window: WindowView | null): string => (window ? `${window.displayPercent}%` : NO_READING);

/** The countdown in the style's voice: words for iris, terse units for dot and mono. */
export function countdown(window: WindowView | null, style: PanelStyle): string {
  return (isMonospaced(style) ? window?.countdownCompact : window?.countdown) ?? NO_READING;
}

/** Iris: the name; dot: its position ("01") before it; mono: a swatch of the tool's colour. `marksBrand` adds a small dot in iris. */
export function providerName(provider: ProviderView, index: number, style: PanelStyle, tint: Rgb, marksBrand = false): HTMLElement {
  const row = el("div", "title-row");
  if (style === "dot") row.append(el("span", "index", String(index + 1).padStart(2, "0")));
  if (style === "mono" || (style === "iris" && marksBrand)) {
    const mark = el("span", style === "mono" ? "swatch" : "brand-dot");
    mark.style.background = rgba(tint, 1);
    row.append(mark);
  }
  row.append(el("span", "name", provider.title));
  return row;
}

/** The subscription plan in small caps; nothing when unknown. */
export function planTag(provider: ProviderView): HTMLElement[] {
  return provider.plan ? [el("span", "plan", provider.plan.toUpperCase())] : [];
}

/** The remaining share as the style's horizontal bar: a light streak, a strip of dots or a row of ticks. */
export function windowBar(style: PanelStyle, width: number, remainingPercent: number, tint: Rgb, drawables: Drawable[]): HTMLCanvasElement {
  const bar: Bar = style === "dot" ? new DotBar(width) : style === "mono" ? new TickBar(width) : new CometBar(width, COMET_THICKNESS);
  bar.update(remainingPercent, tint);
  drawables.push(bar);
  return bar.canvas;
}

/** Dial for the style with the remaining percent in the middle; iris also glows through the glass (see `style.css`). */
export function sessionGauge(window: WindowView | null, style: PanelStyle, tint: Rgb, drawables: Drawable[]): HTMLElement {
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

/** The long window (weekly, monthly): label, share and reset time over the style's bar. */
export function longWindow(provider: ProviderView, style: PanelStyle, tint: Rgb, drawables: Drawable[]): HTMLElement {
  const window = provider.weekly;
  const warning = window ? alert(window.level) : null;
  const share = el("span", "long-share", percentText(window));
  if (warning) share.style.color = rgba(warning, 1);
  const time = isMonospaced(style) ? countdown(window, style) : `${countdown(window, style)} 후`;
  const row = el("div", "long-row", el("span", "long-label", window?.label ?? "장기"), share, el("span", "long-countdown", time));
  return el("div", "long-window", row, windowBar(style, DETAIL_WIDTH, window?.remainingPercent ?? 0, tint, drawables));
}
