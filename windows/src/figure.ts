import { dotMatrixText } from "./dot-matrix";
import { el } from "./dom";
import { WHITE, alert, rgba, type Rgb } from "./theme";
import type { PanelStyle, WindowView } from "./types";

/** Dot pitch as a share of the size: a glyph is seven pitches tall. */
const DOT_PITCH_SHARE = 0.1125;
const DOT_PERCENT_SCALE = 0.55;
const MONO_SCALE = 0.94;
const IRIS_PERCENT_SCALE = 0.44;
const MONO_PERCENT_SCALE = 0.41;
const IRIS_TRACKING = -0.025;
const MUTED_ALPHA = 0.62;
const NO_READING = "–";

/**
 * A large figure in the style's type with a small "%" after it: a display face (iris), LED dots
 * (dot) or monospaced digits (mono). Every layout's large figures go through here, so they share
 * one scale. `size` is the height of the digits in points (the iris font size).
 */
export function styleFigure(text: string, showsPercent: boolean, color: Rgb, size: number, style: PanelStyle): HTMLElement {
  const isDot = style === "dot";
  const parts = isDot ? dotParts(text, showsPercent, color, size) : typeParts(text, showsPercent, color, size, style);
  const inner = el("span", isDot ? "style-figure-line dots" : "style-figure-line", ...parts);
  if (isDot) inner.style.gap = `${size * DOT_PITCH_SHARE}px`;
  const figure = el("div", "style-figure", inner);
  figure.style.height = `${size}px`;
  return figure;
}

/** A window's remaining share as a `styleFigure`, in the warning colours when low and "–" when the window is unknown. */
export function percentFigure(window: WindowView | null, size: number, style: PanelStyle): HTMLElement {
  const color = (window ? alert(window.level) : null) ?? WHITE;
  return styleFigure(window ? String(window.displayPercent) : NO_READING, window !== null, color, size, style);
}

function dotParts(text: string, showsPercent: boolean, color: Rgb, size: number): Node[] {
  const pitch = size * DOT_PITCH_SHARE;
  const parts: Node[] = [dotMatrixText(text, pitch, rgba(color, 1))];
  if (showsPercent) parts.push(dotMatrixText("%", pitch * DOT_PERCENT_SCALE, rgba(WHITE, MUTED_ALPHA)));
  return parts;
}

function typeParts(text: string, showsPercent: boolean, color: Rgb, size: number, style: PanelStyle): Node[] {
  const isMono = style === "mono";
  const digits = el("span", isMono ? "figure-digits mono" : "figure-digits", text);
  digits.style.fontSize = `${isMono ? size * MONO_SCALE : size}px`;
  digits.style.color = rgba(color, 1);
  if (!isMono) digits.style.letterSpacing = `${size * IRIS_TRACKING}px`;
  const parts: Node[] = [digits];
  if (showsPercent) {
    const percent = el("span", "figure-percent", "%");
    percent.style.fontSize = `${size * (isMono ? MONO_PERCENT_SCALE : IRIS_PERCENT_SCALE)}px`;
    parts.push(percent);
  }
  return parts;
}
