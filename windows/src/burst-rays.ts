import { pointAt, prepareCanvas, type Point } from "./canvas";
import { addDisc, fillDisc, lastValueIndex } from "./chart-draw";
import { WHITE, rgba, type Rgb } from "./theme";
import type { PanelStyle } from "./types";

export const BURST_SIZE = 108;
export const BURST_SLICES = 36;

const STUB = 4;
/** The current ray is never shorter than this, so now stays visible in a quiet slice. */
const CURRENT_STUB = 9;
const END_MARGIN = 3;
const DOT_PITCH = 3;
/** Radius of the open middle, as a share of the half size. */
const HOLLOW_SHARE = 0.5;
const PAST_ALPHA = 0.85;
const ARC_ALPHA = 0.18;
const TWELVE_OCLOCK = -Math.PI / 2;
const FULL_TURN = 2 * Math.PI;

interface Ray {
  angle: number;
  from: Point;
  tip: Point;
  length: number;
  heaviness: number;
  isCurrent: boolean;
}

/**
 * A starburst of one window's use: the period runs clockwise from 12 o'clock like a clock face, a
 * ray per slice as long as what was used in it (relative to the heaviest), ending in a dot. Past
 * rays are white, the current one takes the tool's colour and the time still ahead is a faint arc.
 * The middle is left open for the caller's figure. Drawn as flat fine rays (iris), dotted lines
 * (dot) or hairlines with square ends (mono). `values` is % used per slice, null after now.
 */
export function burstRays(values: (number | null)[], tint: Rgb, style: PanelStyle): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  const context = prepareCanvas(canvas, BURST_SIZE, BURST_SIZE);
  const center = { x: BURST_SIZE / 2, y: BURST_SIZE / 2 };
  const base = (BURST_SIZE / 2) * HOLLOW_SHARE;
  const reach = BURST_SIZE / 2 - base - END_MARGIN;
  const peak = Math.max(0, ...values.map((value) => value ?? 0));
  const current = lastValueIndex(values);
  drawArc(context, center, base, current >= 0 ? current + 1 : 0, style);
  values.forEach((value, index) => {
    if (value === null) return;
    const heaviness = peak > 0 ? value / peak : 0;
    const isCurrent = index === current;
    const length = STUB + (reach - STUB) * heaviness;
    const shown = isCurrent ? Math.max(length, CURRENT_STUB) : length;
    const angle = TWELVE_OCLOCK + ((index + 0.5) / BURST_SLICES) * FULL_TURN;
    const ray = { angle, from: pointAt(center, base, angle), tip: pointAt(center, base + shown, angle), length: shown, heaviness, isCurrent };
    const color = rgba(isCurrent ? tint : WHITE, isCurrent ? 1 : PAST_ALPHA);
    if (style === "mono") drawHairline(context, ray, color);
    else if (style === "dot") drawDotted(context, ray, color, center, base);
    else drawFlat(context, ray, color);
  });
  return canvas;
}

function line(context: CanvasRenderingContext2D, ray: Ray, width: number, color: string): void {
  context.strokeStyle = color;
  context.lineWidth = width;
  context.lineCap = "round";
  context.beginPath();
  context.moveTo(ray.from.x, ray.from.y);
  context.lineTo(ray.tip.x, ray.tip.y);
  context.stroke();
}

function drawHairline(context: CanvasRenderingContext2D, ray: Ray, color: string): void {
  context.save();
  context.globalAlpha = 0.7;
  line(context, ray, 0.8, color);
  context.restore();
  const side = 2 + 1.2 * ray.heaviness + (ray.isCurrent ? 0.8 : 0);
  context.fillStyle = color;
  context.fillRect(ray.tip.x - side / 2, ray.tip.y - side / 2, side, side);
}

function drawDotted(context: CanvasRenderingContext2D, ray: Ray, color: string, center: Point, base: number): void {
  const dots = new Path2D();
  for (let step = 0; step < Math.floor(ray.length / DOT_PITCH); step++) addDisc(dots, pointAt(center, base + step * DOT_PITCH, ray.angle), 0.65);
  context.save();
  context.globalAlpha = 0.7;
  context.fillStyle = color;
  context.fill(dots);
  context.restore();
  fillDisc(context, ray.tip, 1.3 + 0.9 * ray.heaviness + (ray.isCurrent ? 0.6 : 0), color);
}

/** Iris: a fine solid ray ending in a dot, no glow. */
function drawFlat(context: CanvasRenderingContext2D, ray: Ray, color: string): void {
  context.save();
  context.globalAlpha = ray.isCurrent ? 0.9 : 0.6;
  line(context, ray, ray.isCurrent ? 1.4 : 0.9, color);
  context.restore();
  fillDisc(context, ray.tip, 1.2 + 1.1 * ray.heaviness + (ray.isCurrent ? 0.6 : 0), color);
}

/** The time still ahead: a faint thin arc on the circle the rays start from, from slice `first` round to 12 o'clock. */
function drawArc(context: CanvasRenderingContext2D, center: Point, radius: number, first: number, style: PanelStyle): void {
  if (first >= BURST_SLICES) return;
  const start = (first / BURST_SLICES) * FULL_TURN + TWELVE_OCLOCK;
  context.beginPath();
  context.arc(center.x, center.y, radius, start, 1.5 * Math.PI);
  context.lineCap = "round";
  if (style === "dot") {
    context.strokeStyle = rgba(WHITE, ARC_ALPHA + 0.1);
    context.lineWidth = 1.2;
    context.setLineDash([0.1, DOT_PITCH]);
  } else {
    context.strokeStyle = rgba(WHITE, ARC_ALPHA);
    context.lineWidth = style === "mono" ? 1 : 0.8;
    context.setLineDash([]);
  }
  context.stroke();
  context.setLineDash([]);
}
