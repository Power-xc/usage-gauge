import { prepareCanvas } from "./canvas";
import { addDisc } from "./chart-draw";
import { WHITE, rgba, type Rgb } from "./theme";
import type { PanelStyle } from "./types";

export const SPARK_HEIGHT = 24;

const DOT_PITCH = 3.6;
const DOT_SIZE = 2.2;
const DOTS_ACROSS = 2;
const SOFT_WIDTH = 3;
const SOFT_PITCH = 6;
const MONO_WIDTH = 1;
const MONO_PITCH = 4;
const DOT_COLUMN_PITCH = 7.2;
const TICK_WIDTH = 1.6;
const BASELINE_ALPHA = 0.16;
const MIN_HEIGHT = 1.5;

/** Slices that fit `width`; used when the history has none to offer. */
export function sparkSlices(width: number, style: PanelStyle): number {
  const pitch = style === "iris" ? SOFT_PITCH : style === "dot" ? DOT_COLUMN_PITCH : MONO_PITCH;
  return Math.floor(width / pitch);
}

/**
 * A strip of thin vertical bars over the window's period, each as tall as what was left at that
 * point: the tool's colour for the past, a contrasting tick at now and faint baseline marks for
 * what is still to come. Drawn as flat soft bars (iris), columns of dots (dot) or 1 pt lines
 * (mono). `values` is remaining % per slice, null before the first reading and after now;
 * `nowIndex` is the slice that holds now.
 */
export function sparkStrip(values: (number | null)[], nowIndex: number | null, tint: Rgb, style: PanelStyle, width: number): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  const context = prepareCanvas(canvas, width, SPARK_HEIGHT);
  const barWidth = style === "iris" ? SOFT_WIDTH : style === "dot" ? DOT_PITCH * (DOTS_ACROSS - 1) + DOT_SIZE : MONO_WIDTH;
  const pitch = (width - barWidth) / Math.max(values.length - 1, 1);
  const [bars, marks, tick] = [new Path2D(), new Path2D(), new Path2D()];
  values.forEach((value, index) => {
    const x = index * pitch;
    if (index === nowIndex) addTick(tick, x + barWidth / 2, style);
    else if (value !== null) addBar(bars, x, barWidth, value / 100, style);
    else addBar(marks, x, barWidth, 0, style);
  });
  context.fillStyle = rgba(WHITE, BASELINE_ALPHA);
  context.fill(marks);
  context.fillStyle = rgba(tint, 1);
  context.fill(bars);
  context.fillStyle = rgba(WHITE, 0.95);
  context.fill(tick);
  return canvas;
}

/** The marker of now: a solid line, or a column of larger dots in the dot style. */
function addTick(path: Path2D, x: number, style: PanelStyle): void {
  if (style !== "dot") {
    path.roundRect(x - TICK_WIDTH / 2, 0, TICK_WIDTH, SPARK_HEIGHT, 0.8);
    return;
  }
  const size = DOT_SIZE * 1.3;
  for (let row = 0; row < Math.floor(SPARK_HEIGHT / DOT_PITCH); row++) {
    addDisc(path, { x, y: SPARK_HEIGHT - row * DOT_PITCH - DOT_SIZE + size / 2 }, size / 2);
  }
}

/** Adds one column filled to `fraction` of the height; zero draws the baseline mark. */
function addBar(path: Path2D, x: number, width: number, fraction: number, style: PanelStyle): void {
  const filled = Math.max(MIN_HEIGHT, SPARK_HEIGHT * fraction);
  if (style === "iris") {
    path.roundRect(x, SPARK_HEIGHT - filled, width, filled, width / 2);
  } else if (style === "mono") {
    path.rect(x, SPARK_HEIGHT - filled, width, filled);
  } else {
    const rows = Math.floor(SPARK_HEIGHT / DOT_PITCH);
    const lit = fraction > 0 ? Math.max(1, Math.round(fraction * rows)) : 1;
    for (let row = 0; row < lit; row++) {
      for (let across = 0; across < DOTS_ACROSS; across++) {
        addDisc(path, { x: x + across * DOT_PITCH + DOT_SIZE / 2, y: SPARK_HEIGHT - row * DOT_PITCH - DOT_SIZE / 2 }, DOT_SIZE / 2);
      }
    }
  }
}
