import { prepareCanvas } from "./canvas";
import { addDisc, lastValueIndex } from "./chart-draw";
import { WHITE, rgba, type Rgb } from "./theme";
import type { PanelStyle } from "./types";

export const HISTOGRAM_HEIGHT = 44;

const DOTS_ACROSS = 2;
const DOT_SHARE = 0.72;
const SEGMENT_PITCH = 3.2;
const SEGMENT_HEIGHT = 1.4;
const SOFT_WIDTH_SHARE = 0.5;
const BASELINE_HEIGHT = 2;
const PAST_ALPHA = 0.88;
const IDLE_ALPHA = 0.4;
const FUTURE_ALPHA = 0.14;
const DIVIDER_ALPHA = 0.16;

type Kind = "past" | "current" | "idlePast" | "idleCurrent" | "future";

/**
 * A row of vertical columns, one per slice of the window, evenly pitched across the cell and each
 * as tall as what was used in it relative to the tallest. Past slices are white, the current one
 * takes the tool's colour, a faint divider marks now and slices still to come are faint baseline
 * marks. Drawn as soft bars (iris), dotted columns on one lattice (dot) or stacked thin segments
 * (mono). `values` is % used per slice, null for slices after now.
 */
export function histogramColumns(values: (number | null)[], tint: Rgb, style: PanelStyle, width: number): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  const context = prepareCanvas(canvas, width, HISTOGRAM_HEIGHT);
  const pitch = width / Math.max(values.length, 1);
  const peak = Math.max(0, ...values.map((value) => value ?? 0));
  const current = lastValueIndex(values);
  const paths: Record<Kind, Path2D> = { past: new Path2D(), current: new Path2D(), idlePast: new Path2D(), idleCurrent: new Path2D(), future: new Path2D() };
  values.forEach((value, index) => {
    const fraction = peak > 0 ? (value ?? 0) / peak : 0;
    const isIdle = fraction <= 0;
    const kind: Kind = value === null ? "future" : index === current ? (isIdle ? "idleCurrent" : "current") : isIdle ? "idlePast" : "past";
    const column = columnRect(index, pitch, style);
    if (style === "iris") {
      const height = isIdle ? BASELINE_HEIGHT : Math.max(column.width, HISTOGRAM_HEIGHT * fraction);
      paths[kind].roundRect(column.x, HISTOGRAM_HEIGHT - height, column.width, height, column.width / 2);
    } else {
      addCells(paths[kind], column, fraction, isIdle, pitch, style);
    }
  });
  if (current >= 0) drawDivider(context, (current + 1) * pitch, width, pitch, style);
  const fill = (kind: Kind, color: string): void => {
    context.fillStyle = color;
    context.fill(paths[kind]);
  };
  fill("future", rgba(WHITE, FUTURE_ALPHA));
  fill("idlePast", rgba(WHITE, IDLE_ALPHA));
  fill("idleCurrent", rgba(tint, 0.6));
  fill("past", rgba(WHITE, PAST_ALPHA));
  fill("current", rgba(tint, 1));
  return canvas;
}

const dotPitch = (pitch: number): number => pitch / (DOTS_ACROSS + 1);

function columnRect(index: number, pitch: number, style: PanelStyle): { x: number; width: number } {
  const width = style === "dot" ? dotPitch(pitch) * (DOTS_ACROSS - 1 + DOT_SHARE) : pitch * SOFT_WIDTH_SHARE;
  return { x: index * pitch + (pitch - width) / 2, width };
}

/** Fills the dots or segments of one column from the bottom up; an idle slice is the bottom cell alone. */
function addCells(path: Path2D, column: { x: number; width: number }, fraction: number, isIdle: boolean, pitch: number, style: PanelStyle): void {
  const isDot = style === "dot";
  const step = isDot ? dotPitch(pitch) : SEGMENT_PITCH;
  const cell = isDot ? step * DOT_SHARE : SEGMENT_HEIGHT;
  const lit = isIdle ? 1 : Math.max(1, Math.round(fraction * Math.floor(HISTOGRAM_HEIGHT / step)));
  for (let row = 0; row < lit; row++) {
    const y = HISTOGRAM_HEIGHT - row * step - cell;
    if (isDot) {
      for (let across = 0; across < DOTS_ACROSS; across++) addDisc(path, { x: column.x + across * step + cell / 2, y: y + cell / 2 }, cell / 2);
    } else {
      path.rect(column.x, y, column.width, cell);
    }
  }
}

/** A faint line (dots in the dot style) between now and the slices to come. */
function drawDivider(context: CanvasRenderingContext2D, x: number, width: number, pitch: number, style: PanelStyle): void {
  if (x >= width) return;
  context.fillStyle = rgba(WHITE, DIVIDER_ALPHA);
  if (style === "dot") {
    const dots = new Path2D();
    const step = dotPitch(pitch) * 2;
    for (let y = HISTOGRAM_HEIGHT - step / 2; y >= 0; y -= step) addDisc(dots, { x, y }, 0.5);
    context.fill(dots);
  } else {
    context.fillRect(Math.round(x) - 0.5, 0, 1, HISTOGRAM_HEIGHT);
  }
}
