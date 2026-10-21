import "./history.css";
import { dotMatrixText } from "../dot-matrix";
import { el } from "../dom";
import { WHITE, alert, rgba, type Rgb } from "../theme";
import type { PanelStyle, ProviderView, WindowView } from "../types";
import { revealingCaption } from "../reveal";
import { NO_READING, planTag, providerName } from "./parts";

/** Dot pitch of a large figure as a share of its size: a glyph is seven pitches tall. */
const DOT_PITCH_SHARE = 0.1125;
const DOT_PERCENT_SCALE = 0.55;
export const MUTED_ALPHA = 0.62;
/** Digit height of the large figures of the trend and histogram layouts. */
export const FIGURE_SIZE = 32;

/** A large figure in the style's type with a small "%" after it: a display face (iris), LED dots (dot) or monospaced digits (mono). `size` is the digit height in points of the iris face. */
export function styleFigure(text: string, showsPercent: boolean, color: Rgb | null, size: number, style: PanelStyle): HTMLElement {
  const figure = el("div", "style-figure");
  if (style === "dot") {
    const pitch = size * DOT_PITCH_SHARE;
    figure.classList.add("dotted");
    figure.style.gap = `${pitch}px`;
    figure.append(dotMatrixText(text, pitch, rgba(color ?? WHITE, 1)));
    if (showsPercent) figure.append(dotMatrixText("%", pitch * DOT_PERCENT_SCALE, rgba(WHITE, MUTED_ALPHA)));
    return figure;
  }
  figure.style.setProperty("--size", String(size));
  const digits = el("span", "digits", text);
  if (color) digits.style.color = rgba(color, 1);
  figure.append(digits);
  if (showsPercent) figure.append(el("span", "pct", "%"));
  return figure;
}

/** A window's remaining share as a large figure, in the warning colours when low and "–" when unknown. */
export function percentFigure(window: WindowView | null, size: number, style: PanelStyle): HTMLElement {
  return styleFigure(window ? String(window.displayPercent) : NO_READING, window !== null, window ? alert(window.level) : null, size, style);
}

/** The tool's name with its plan beside it. With a `revealWidth` (the cell's), a hover swaps the plan for the reset and measuring times. */
export function nameRow(provider: ProviderView, index: number, style: PanelStyle, tint: Rgb, revealWidth?: number): HTMLElement {
  const plan = revealWidth === undefined ? planTag(provider) : [revealingCaption(provider, planTag(provider)[0] ?? null, { width: revealWidth })];
  return el("div", "history-name", providerName(provider, index, style, tint, true), ...plan);
}

/** Small status at the end of a footer: a dot and the projected run-out in the alert colour, or "여유". Light and colour only, no frame. */
export function statusPill(text: string, color: string): HTMLElement {
  const dot = el("i", "");
  dot.style.background = color;
  const pill = el("span", "status-pill", dot, text);
  pill.style.color = color;
  return pill;
}

/** Shown in place of a chart while the history holds too little to draw. */
export const recordingNote = (): HTMLElement => el("div", "recording-note", "기록 중 · 2분마다 쌓여요");

/** A chart canvas with a note over it while the history is still too short. */
export function chartSlot(canvas: HTMLCanvasElement, isRecording: boolean): HTMLElement {
  const slot = el("div", "chart-slot", canvas);
  if (isRecording) slot.append(recordingNote());
  return slot;
}
