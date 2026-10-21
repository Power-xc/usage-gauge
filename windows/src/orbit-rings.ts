import { prepareCanvas, pointAt, type Point } from "./canvas";
import { WHITE, rgba, type Rgb } from "./theme";
import type { PanelStyle } from "./types";

/** One ring of the orbit chart: the short window's remaining share in the tool's colour, or null for a tool that reports nothing (an empty track). */
export interface OrbitRing {
  remainingPercent: number | null;
  tint: Rgb;
}

/** Room kept free in the middle for the figure. */
const MIN_INNER_RADIUS = 36;
const MAX_PITCH = 8.5;
const EDGE_INSET = 3;
const DOT_SPACING = 4.4;
const TICK_SPACING = 3.1;
const DIM_ALPHA = 0.13;
const TWELVE_OCLOCK = -Math.PI / 2;
const FULL_TURN = 2 * Math.PI;

const pitchOf = (ringCount: number, size: number): number =>
  Math.min(MAX_PITCH, (size / 2 - EDGE_INSET - MIN_INNER_RADIUS) / Math.max(ringCount, 1));

/** Radius of the space left free in the middle. */
export const innerRadius = (ringCount: number, size: number): number => size / 2 - EDGE_INSET - pitchOf(ringCount, size) * ringCount;

/**
 * Concentric rings, the first outermost, each lit clockwise from 12 o'clock: rings of dots (dot),
 * of thin radial ticks (mono) or solid arcs over faint tracks (iris). A white head marks the end
 * of every lit arc. Still.
 */
export function orbitRings(style: PanelStyle, rings: OrbitRing[], size: number): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  const context = prepareCanvas(canvas, size, size);
  const center = { x: size / 2, y: size / 2 };
  const pitch = pitchOf(rings.length, size);
  rings.forEach((ring, index) => {
    const radius = size / 2 - EDGE_INSET - pitch * (index + 0.5);
    const share = (ring.remainingPercent ?? 0) / 100;
    if (style === "dot") drawDots(context, center, radius, pitch, ring, share);
    else if (style === "mono") drawTicks(context, center, radius, pitch, ring, share);
    else drawArc(context, center, radius, pitch, ring, share);
  });
  return canvas;
}

const angleOf = (step: number, count: number): number => (step / count) * FULL_TURN + TWELVE_OCLOCK;

function drawDots(context: CanvasRenderingContext2D, center: Point, radius: number, pitch: number, ring: OrbitRing, share: number): void {
  const count = Math.max(12, Math.floor((FULL_TURN * radius) / DOT_SPACING));
  const lit = Math.round(share * count);
  const dot = Math.min(2.7, pitch * 0.5);
  const [dimmed, tinted, head] = [new Path2D(), new Path2D(), new Path2D()];
  for (let step = 0; step < count; step++) {
    const size = step === lit - 1 ? dot * 1.7 : dot;
    const at = pointAt(center, radius, angleOf(step, count));
    const target = step >= lit ? dimmed : step === lit - 1 ? head : tinted;
    target.moveTo(at.x + size / 2, at.y);
    target.arc(at.x, at.y, size / 2, 0, FULL_TURN);
  }
  context.fillStyle = rgba(WHITE, DIM_ALPHA);
  context.fill(dimmed);
  context.fillStyle = rgba(ring.tint, 1);
  context.fill(tinted);
  context.fillStyle = rgba(WHITE, 1);
  context.fill(head);
}

function drawTicks(context: CanvasRenderingContext2D, center: Point, radius: number, pitch: number, ring: OrbitRing, share: number): void {
  const count = Math.max(24, Math.floor((FULL_TURN * radius) / TICK_SPACING));
  const lit = Math.round(share * count);
  const length = Math.min(8, pitch * 0.75);
  const [dimmed, tinted, head] = [new Path2D(), new Path2D(), new Path2D()];
  for (let step = 0; step < count; step++) {
    const tilt = angleOf(step, count);
    const reach = step === lit - 1 ? length * 1.35 : length;
    const from = pointAt(center, radius - length / 2, tilt);
    const to = pointAt(center, radius - length / 2 + reach, tilt);
    const target = step >= lit ? dimmed : step === lit - 1 ? head : tinted;
    target.moveTo(from.x, from.y);
    target.lineTo(to.x, to.y);
  }
  context.lineCap = "butt";
  context.lineWidth = 1.3;
  context.strokeStyle = rgba(WHITE, DIM_ALPHA);
  context.stroke(dimmed);
  context.strokeStyle = rgba(ring.tint, 1);
  context.stroke(tinted);
  context.lineWidth = 1.9;
  context.strokeStyle = rgba(WHITE, 1);
  context.stroke(head);
}

function drawArc(context: CanvasRenderingContext2D, center: Point, radius: number, pitch: number, ring: OrbitRing, share: number): void {
  const width = Math.min(3.2, pitch * 0.5);
  context.lineWidth = width;
  context.strokeStyle = rgba(WHITE, 0.09);
  context.beginPath();
  context.arc(center.x, center.y, radius, 0, FULL_TURN);
  context.stroke();
  if (share <= 0) return;
  const end = TWELVE_OCLOCK + FULL_TURN * share;
  context.lineCap = "round";
  context.strokeStyle = rgba(ring.tint, 1);
  context.beginPath();
  context.arc(center.x, center.y, radius, TWELVE_OCLOCK, end);
  context.stroke();
  const tip = pointAt(center, radius, end);
  context.fillStyle = rgba(WHITE, 1);
  context.beginPath();
  context.arc(tip.x, tip.y, width * 0.55, 0, FULL_TURN);
  context.fill();
}
