import { prepareCanvas, type Point } from "./canvas";
import { FIELD, FRAME, GUTTER_WIDTH } from "./constellation-plot";
import { REACH, MARKER_SIZE, type TagPlacement } from "./layouts/tag-layout";
import { FONT_MONO, FONT_SANS, WHITE, rgba, type Rgb } from "./theme";
import type { PanelStyle } from "./types";

const TICK_LENGTH = 4;
const TICKS = [0, 0.5, 1];
const DOT_PITCH = 12;
const HINT_ALPHA = 0.3;
const MINIMUM_TRAIL = 5;
const LINK_ALPHA = 0.6;
const IRIS_LINK_ALPHA = 0.3;
const MARKER_DOT_PITCH = 3.1;
const MARKER_DOT_SIZE = 2.3;
const IRIS_RING_SIZE = 13;
const FULL_TURN = 2 * Math.PI;
const CAPTION_Y = 14;

/** One tool's drawing: where it is, where it stood an hour ago, and where its tag sits. */
export interface FieldStar {
  tint: Rgb;
  point: Point;
  past: Point | null;
  placement: TagPlacement;
}

/**
 * The still part of the constellation: the quiet scaffolding (hairline axes with ticks at 0, 50
 * and 100, a faint cross at the middle, corner hints and captions), the trails and links between
 * tools, and every node's leader and marker. The tags are elements above it. Iris keeps lines
 * solid: white links and trails in the tool's colour, without glow.
 */
export function constellationField(style: PanelStyle, stars: FieldStar[], footnote: string | null): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  const context = prepareCanvas(canvas, FRAME.width, FRAME.height);
  if (style === "dot") drawDotGrid(context);
  else drawAxes(context, style);
  drawLabels(context, style, footnote);
  for (const star of stars) if (star.past) drawTrail(context, style, star.tint, star.point, star.past);
  const path = [...stars].sort((a, b) => a.point.x - b.point.x);
  path.slice(1).forEach((to, index) => drawLink(context, style, path[index], to));
  for (const star of stars) {
    drawLeader(context, style, star);
    drawMarker(context, style, star.tint, star.point);
  }
  return canvas;
}

/** Hairline at `y` or `x` snapped to the pixel grid. */
const snap = (value: number): number => Math.round(value) + 0.5;

/** Mono and iris: an L of hairlines with ticks outside, and a cross through the middle. */
function drawAxes(context: CanvasRenderingContext2D, style: PanelStyle): void {
  const isIris = style === "iris";
  const left = snap(FIELD.left);
  const bottom = snap(FIELD.bottom);
  const [axes, marks, middle] = [new Path2D(), new Path2D(), new Path2D()];
  axes.moveTo(left, FIELD.top);
  axes.lineTo(left, bottom);
  axes.moveTo(FIELD.left, bottom);
  axes.lineTo(FIELD.right, bottom);
  for (const tick of TICKS) {
    const y = snap(FIELD.bottom - tick * FIELD.height);
    const x = snap(FIELD.left + tick * FIELD.width);
    marks.moveTo(left - TICK_LENGTH, y);
    marks.lineTo(left, y);
    marks.moveTo(x, bottom);
    marks.lineTo(x, bottom + TICK_LENGTH);
  }
  middle.moveTo(FIELD.left, snap(FIELD.midY));
  middle.lineTo(FIELD.right, snap(FIELD.midY));
  middle.moveTo(snap(FIELD.midX), FIELD.top);
  middle.lineTo(snap(FIELD.midX), FIELD.bottom);
  context.lineWidth = 1;
  context.strokeStyle = rgba(WHITE, isIris ? 0.07 : 0.06);
  context.stroke(middle);
  context.strokeStyle = rgba(WHITE, isIris ? 0.16 : 0.2);
  context.stroke(axes);
  context.stroke(marks);
}

/** Dot: a grid of faint dots, brighter along the axes. */
function drawDotGrid(context: CanvasRenderingContext2D): void {
  const columns = Math.floor(FIELD.width / DOT_PITCH);
  const rows = Math.floor(FIELD.height / DOT_PITCH);
  const [faint, axis] = [new Path2D(), new Path2D()];
  for (let column = 0; column <= columns; column++) {
    for (let row = 0; row <= rows; row++) {
      const x = FIELD.left + column * DOT_PITCH;
      const y = FIELD.bottom - row * DOT_PITCH;
      const isAxis = column === 0 || row === 0;
      const radius = isAxis ? 1.1 : 0.8;
      const target = isAxis ? axis : faint;
      target.moveTo(x + radius, y);
      target.arc(x, y, radius, 0, FULL_TURN);
    }
  }
  context.fillStyle = rgba(WHITE, 0.07);
  context.fill(faint);
  context.fillStyle = rgba(WHITE, 0.2);
  context.fill(axis);
}

/** Corner hints, the axes' captions and, for tools that report nothing, a line naming them. */
function drawLabels(context: CanvasRenderingContext2D, style: PanelStyle, footnote: string | null): void {
  const family = style === "iris" ? FONT_SANS : FONT_MONO;
  context.font = `500 8.5px ${family}`;
  context.textBaseline = "middle";
  context.letterSpacing = "0.6px";
  context.fillStyle = rgba(WHITE, HINT_ALPHA);
  context.textAlign = "center";
  context.fillText("여유", FIELD.right - 12, FIELD.top + 8);
  context.fillText("부족", FIELD.left + 12, FIELD.bottom - 8);
  context.letterSpacing = "0px";
  context.fillStyle = rgba(WHITE, 0.42);
  context.textAlign = "left";
  context.fillText("장기 ↑", 0, FIELD.top, GUTTER_WIDTH - 4);
  if (footnote) context.fillText(footnote, FIELD.left, FIELD.bottom + CAPTION_Y);
  context.textAlign = "right";
  context.fillText("단기 →", FIELD.right, FIELD.bottom + CAPTION_Y);
}

function drawLink(context: CanvasRenderingContext2D, style: PanelStyle, from: FieldStar, to: FieldStar): void {
  const line = new Path2D();
  line.moveTo(from.point.x, from.point.y);
  line.lineTo(to.point.x, to.point.y);
  const shading = (alpha: number) => {
    const gradient = context.createLinearGradient(from.point.x, from.point.y, to.point.x, to.point.y);
    gradient.addColorStop(0, rgba(from.tint, alpha));
    gradient.addColorStop(1, rgba(to.tint, alpha));
    return gradient;
  };
  context.lineCap = "butt";
  context.setLineDash([]);
  if (style === "mono") {
    context.strokeStyle = shading(LINK_ALPHA);
    context.lineWidth = 1;
  } else if (style === "dot") {
    context.strokeStyle = shading(0.8);
    context.lineWidth = 1.7;
    context.lineCap = "round";
    context.setLineDash([0.01, 4.4]);
  } else {
    context.strokeStyle = rgba(WHITE, IRIS_LINK_ALPHA);
    context.lineWidth = 0.9;
  }
  context.stroke(line);
  context.setLineDash([]);
}

/** From the old place, faint, to the node, strongest: the fade points the way it moved. */
function drawTrail(context: CanvasRenderingContext2D, style: PanelStyle, tint: Rgb, point: Point, past: Point): void {
  if (Math.hypot(point.x - past.x, point.y - past.y) < MINIMUM_TRAIL) return;
  const line = new Path2D();
  line.moveTo(past.x, past.y);
  line.lineTo(point.x, point.y);
  const fade = context.createLinearGradient(past.x, past.y, point.x, point.y);
  fade.addColorStop(0, rgba(tint, 0.1));
  fade.addColorStop(1, rgba(tint, 0.75));
  const ghost = new Path2D();
  context.lineCap = "butt";
  context.setLineDash([]);
  if (style === "mono") {
    ghost.rect(past.x - 2.5, past.y - 2.5, 5, 5);
    context.strokeStyle = fade;
    context.lineWidth = 1;
    context.stroke(line);
    context.strokeStyle = rgba(tint, 0.55);
    context.stroke(ghost);
    return;
  }
  ghost.arc(past.x, past.y, 2.5, 0, FULL_TURN);
  if (style === "dot") {
    context.strokeStyle = fade;
    context.lineWidth = 1.4;
    context.lineCap = "round";
    context.setLineDash([0.01, 3.2]);
    context.stroke(line);
    context.setLineDash([]);
    context.strokeStyle = rgba(tint, 0.5);
    context.lineWidth = 1;
  } else {
    context.strokeStyle = rgba(tint, 0.4);
    context.lineWidth = 1.2;
    context.lineCap = "round";
    context.stroke(line);
    context.lineWidth = 0.8;
  }
  context.stroke(ghost);
}

function drawLeader(context: CanvasRenderingContext2D, style: PanelStyle, star: FieldStar): void {
  const direction = star.placement.side === "right" ? 1 : -1;
  const line = new Path2D();
  line.moveTo(star.point.x, star.point.y);
  line.lineTo(star.point.x + direction * REACH, star.point.y + star.placement.offset);
  context.lineCap = "butt";
  context.setLineDash([]);
  if (style === "mono") {
    context.strokeStyle = rgba(star.tint, 0.7);
    context.lineWidth = 1;
  } else if (style === "dot") {
    context.strokeStyle = rgba(star.tint, 0.8);
    context.lineWidth = 1.5;
    context.lineCap = "round";
    context.setLineDash([0.01, 3]);
  } else {
    context.strokeStyle = rgba(star.tint, 0.6);
    context.lineWidth = 0.8;
  }
  context.stroke(line);
  context.setLineDash([]);
}

/** A solid square (mono), a cluster of dots (dot) or a solid point in a thin ring (iris). */
function drawMarker(context: CanvasRenderingContext2D, style: PanelStyle, tint: Rgb, at: Point): void {
  if (style === "mono") {
    context.fillStyle = rgba(tint, 1);
    context.fillRect(at.x - MARKER_SIZE / 2, at.y - MARKER_SIZE / 2, MARKER_SIZE, MARKER_SIZE);
  } else if (style === "dot") {
    for (let row = -1; row <= 1; row++) {
      for (let column = -1; column <= 1; column++) {
        const isCorner = row !== 0 && column !== 0;
        context.fillStyle = rgba(tint, isCorner ? 0.55 : 1);
        context.beginPath();
        context.arc(at.x + column * MARKER_DOT_PITCH, at.y + row * MARKER_DOT_PITCH, MARKER_DOT_SIZE / 2, 0, FULL_TURN);
        context.fill();
      }
    }
  } else {
    context.strokeStyle = rgba(tint, 0.55);
    context.lineWidth = 1;
    context.beginPath();
    context.arc(at.x, at.y, IRIS_RING_SIZE / 2 - 0.5, 0, FULL_TURN);
    context.stroke();
    context.fillStyle = rgba(tint, 1);
    context.beginPath();
    context.arc(at.x, at.y, (MARKER_SIZE - 1) / 2, 0, FULL_TURN);
    context.fill();
  }
}
