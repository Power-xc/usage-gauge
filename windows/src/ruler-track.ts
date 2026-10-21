import { prepareCanvas, type Point } from "./canvas";
import { FONT_MONO, FONT_SANS, WHITE, rgba, type Rgb } from "./theme";
import type { PanelStyle } from "./types";

/** Where the geometry of the ruler is read by the figure beside it. */
export const SPINE_X = 30;
export const KNOB_RADIUS = 6.5;
/** How far the line stands off the spine at the knob. */
const BULGE = 11;
/** Room above and below the ruler for the figure that sits at its ends. */
const END_PADDING = 16;
/** Where the figure beside the knob starts. */
export const FIGURE_X = SPINE_X + BULGE + KNOB_RADIUS;

const BUMP_HALF_WIDTH = 30;
const END_TAPER = 10;
/** The knob sits a little right of the spine, inside the bulge. */
const KNOB_SHIFT = 1.5;
const LONG_TICK = 8;
const SHORT_TICK = 4;
const TICK_GAP = 4;
const NOTCH_LENGTH = 15;
const NOTCH_LABEL_CLEARANCE = 8;
const DOT_PITCH = 3.8;
const FAINT_OPACITY = 0.4;
const FADE_LENGTH = 22;
const KNOB_RING_DOTS = 12;
const LINE_STEP = 0.5;
const FULL_TURN = 2 * Math.PI;

/** Height of `share` (0...100) from the top of a ruler `height` points tall. */
export function shareY(share: number, height: number): number {
  return END_PADDING + (height - 2 * END_PADDING) * (1 - share / 100);
}

export interface RulerReadings {
  tint: Rgb;
  /** One syllable naming the long window; null hides the notch. */
  notchLabel: string | null;
  /** Whether the line and knob are drawn; off for a tool without a short window. */
  isActive: boolean;
  remaining: number;
  longRemaining: number;
}

/**
 * A vertical ruler from 0 at the bottom to 100 at the top: numbered long ticks every 25, short
 * ticks every 5, and a line in the tool's colour running up to the short window's share. The line
 * bulges outward in a smooth bump around a round knob at that share and fades out above it; the
 * long window is a small notch on the ticks' side. Drawn as a solid line and a flat dark knob with a
 * fine rim (iris), a 1 px line and a hollow knob (mono) or dots and a ring of dots (dot). Still.
 */
export function rulerTrack(style: PanelStyle, readings: RulerReadings, width: number, height: number): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  const context = prepareCanvas(canvas, width, height);
  const { isActive, remaining, longRemaining, notchLabel } = readings;
  const knobY = shareY(remaining, height);
  const notchY = notchLabel === null ? null : shareY(longRemaining, height);
  drawTicks(context, style, height, notchY);
  if (notchY !== null && notchLabel !== null) drawNotch(context, style, readings.tint, notchY, notchLabel);
  if (!isActive) return canvas;
  const line = bumpLine(knobY, END_PADDING, height - END_PADDING);
  drawLine(context, style, readings.tint, line, knobY);
  drawKnob(context, style, readings.tint, { x: SPINE_X + KNOB_SHIFT, y: knobY });
  return canvas;
}

/** The line down the ruler, two points per point of height, pushed right by a raised-cosine bump centred on the knob. */
function bumpLine(knobY: number, top: number, bottom: number): Point[] {
  const points: Point[] = [];
  for (let y = top; y <= bottom; y += LINE_STEP) {
    const u = Math.min(1, Math.abs(y - knobY) / BUMP_HALF_WIDTH);
    // Back on the spine at the ends, so the line never leaves the ruler there.
    const taper = Math.min(1, (y - top) / END_TAPER, (bottom - y) / END_TAPER);
    points.push({ x: SPINE_X + (BULGE * taper * (1 + Math.cos(Math.PI * u))) / 2, y });
  }
  return points;
}

/** How strongly the line shows at `y`: full up to the knob, fading out above it. */
function strength(y: number, knobY: number): number {
  const above = Math.max(0, knobY - y - 4);
  return 1 - (1 - FAINT_OPACITY) * Math.min(1, above / FADE_LENGTH);
}

function tracePath(points: Point[]): Path2D {
  const path = new Path2D();
  points.forEach((point, index) => (index === 0 ? path.moveTo(point.x, point.y) : path.lineTo(point.x, point.y)));
  return path;
}

function drawLine(context: CanvasRenderingContext2D, style: PanelStyle, tint: Rgb, points: Point[], knobY: number): void {
  const [first, last] = [points[0], points[points.length - 1]];
  if (!first || !last) return;
  if (style === "dot") {
    drawDots(context, tint, points, knobY);
  } else if (style === "mono") {
    const span = Math.max(1, last.y - first.y);
    const location = (y: number) => Math.min(1, Math.max(0, (y - first.y) / span));
    const fade = context.createLinearGradient(first.x, first.y, last.x, last.y);
    fade.addColorStop(location(knobY - 4 - FADE_LENGTH), rgba(tint, FAINT_OPACITY));
    fade.addColorStop(location(knobY - 4), rgba(tint, 1));
    context.strokeStyle = fade;
    context.lineWidth = 1;
    context.stroke(tracePath(points));
  } else {
    // Two solid strokes meeting at the bulge: faint above the knob, full below it.
    const found = points.findIndex((point) => point.y >= knobY);
    const split = found < 0 ? points.length - 1 : found;
    context.lineWidth = 1.6;
    context.lineCap = "round";
    context.lineJoin = "round";
    context.strokeStyle = rgba(tint, FAINT_OPACITY);
    context.stroke(tracePath(points.slice(0, split + 1)));
    context.strokeStyle = rgba(tint, 1);
    context.stroke(tracePath(points.slice(split)));
  }
}

/** Dots at an even spacing along the line, as far apart along the bump as on the straight. */
function drawDots(context: CanvasRenderingContext2D, tint: Rgb, points: Point[], knobY: number): void {
  let travelled = 0;
  let next = 0;
  let previous = points[0];
  for (const point of points) {
    travelled += Math.hypot(point.x - previous.x, point.y - previous.y);
    previous = point;
    if (travelled < next) continue;
    next += DOT_PITCH;
    if (Math.hypot(point.x - (SPINE_X + KNOB_SHIFT), point.y - knobY) < KNOB_RADIUS + 2) continue;
    context.fillStyle = rgba(tint, strength(point.y, knobY));
    context.beginPath();
    context.arc(point.x, point.y, 1, 0, FULL_TURN);
    context.fill();
  }
}

function drawKnob(context: CanvasRenderingContext2D, style: PanelStyle, tint: Rgb, center: Point): void {
  const disc = new Path2D();
  disc.arc(center.x, center.y, KNOB_RADIUS, 0, FULL_TURN);
  const rim = new Path2D();
  rim.arc(center.x, center.y, KNOB_RADIUS - 0.5, 0, FULL_TURN);
  context.lineWidth = 1;
  if (style === "mono") {
    context.fillStyle = "#000";
    context.fill(disc);
    context.strokeStyle = rgba(tint, 1);
    context.stroke(rim);
  } else if (style === "iris") {
    context.fillStyle = "rgba(10, 10, 10, 0.95)";
    context.fill(disc);
    context.strokeStyle = rgba(WHITE, 0.6);
    context.stroke(rim);
  } else {
    const ring = new Path2D();
    for (let index = 0; index < KNOB_RING_DOTS; index++) {
      const angle = (index / KNOB_RING_DOTS) * FULL_TURN;
      const x = center.x + (KNOB_RADIUS - 0.5) * Math.cos(angle);
      const y = center.y + (KNOB_RADIUS - 0.5) * Math.sin(angle);
      ring.moveTo(x + 1, y);
      ring.arc(x, y, 1, 0, FULL_TURN);
    }
    context.fillStyle = rgba(tint, 1);
    context.fill(ring);
  }
}

function drawTicks(context: CanvasRenderingContext2D, style: PanelStyle, height: number, notchY: number | null): void {
  const right = SPINE_X - TICK_GAP;
  const [long, short] = [new Path2D(), new Path2D()];
  context.font = `400 7px ${FONT_MONO}`;
  context.textAlign = "right";
  context.textBaseline = "middle";
  context.fillStyle = rgba(WHITE, 0.42);
  for (let share = 0; share <= 100; share += 5) {
    const isLong = share % 25 === 0;
    const y = shareY(share, height);
    const target = isLong ? long : short;
    if (style === "dot") {
      for (let index = 0; index < (isLong ? 3 : 1); index++) {
        const x = right - index * 3.6;
        target.moveTo(x + 0.9, y);
        target.arc(x, y, 0.9, 0, FULL_TURN);
      }
    } else {
      const snapped = style === "mono" ? Math.round(y) + 0.5 : y;
      target.moveTo(right - (isLong ? LONG_TICK : SHORT_TICK), snapped);
      target.lineTo(right, snapped);
    }
    if (isLong && (notchY === null || Math.abs(notchY - y) > NOTCH_LABEL_CLEARANCE)) {
      context.fillText(String(share), right - LONG_TICK - 4, y);
    }
  }
  if (style === "dot") {
    context.fillStyle = rgba(WHITE, 0.22);
    context.fill(short);
    context.fillStyle = rgba(WHITE, 0.5);
    context.fill(long);
    return;
  }
  context.lineWidth = style === "iris" ? 0.8 : 1;
  context.strokeStyle = rgba(WHITE, 0.2);
  context.stroke(short);
  context.strokeStyle = rgba(WHITE, 0.42);
  context.stroke(long);
}

function drawNotch(context: CanvasRenderingContext2D, style: PanelStyle, tint: Rgb, y: number, label: string): void {
  const right = SPINE_X - TICK_GAP + 2;
  const left = right - NOTCH_LENGTH;
  context.fillStyle = rgba(tint, 1);
  if (style === "mono") {
    context.fillRect(left, Math.round(y) - 0.5, NOTCH_LENGTH, 2);
  } else if (style === "iris") {
    context.beginPath();
    context.roundRect(left, y - 1.1, NOTCH_LENGTH, 2.2, 1.1);
    context.fill();
  } else {
    const dots = new Path2D();
    for (let index = 0; index < 4; index++) {
      const x = right - index * 4.2;
      dots.moveTo(x + 1.2, y);
      dots.arc(x, y, 1.2, 0, FULL_TURN);
    }
    context.fill(dots);
  }
  context.font = `600 7.5px ${style === "iris" ? FONT_SANS : FONT_MONO}`;
  context.textAlign = "right";
  context.textBaseline = "middle";
  context.fillText(label, left - 3, y);
}
