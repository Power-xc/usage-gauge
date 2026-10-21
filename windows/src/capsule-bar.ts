import { prepareCanvas } from "./canvas";
import { WHITE, rgba, type Rgb } from "./theme";
import type { PanelStyle } from "./types";

export const CAPSULE_HEIGHT = 22;

const DOT_PITCH = 4;
const DOT_ROWS = 5;
const DOT_SIZE = 2.5;
const SEGMENT_PITCH = 4;
const SEGMENT_WIDTH = 2;
const BRAND_SEGMENTS = 2;
const INSET = 3;
const HEAD_SHARE = 0.4;
const FULL_TURN = 2 * Math.PI;

/**
 * A horizontal capsule filled from the left to the remaining share in the tool's colour, the
 * used part faint: dots (dot), upright segments with a brand-coloured last one (mono) or a flat
 * pane holding a solid fill that ends in a white dot (iris). Still; it is drawn once.
 */
export function capsuleBar(style: PanelStyle, width: number, remainingPercent: number, tint: Rgb): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  const context = prepareCanvas(canvas, width, CAPSULE_HEIGHT);
  const share = Math.min(100, Math.max(0, remainingPercent)) / 100;
  if (style === "dot") drawDots(context, width, share, tint);
  else if (style === "mono") drawSegments(context, width, share, tint);
  else drawFlat(context, width, share, tint);
  return canvas;
}

function stadium(context: CanvasRenderingContext2D, x: number, y: number, width: number, height: number): void {
  context.beginPath();
  context.roundRect(x, y, width, height, height / 2);
}

/** Dots on a grid, kept where they fall inside the capsule; the outermost ring of the grid is the outline. */
function drawDots(context: CanvasRenderingContext2D, width: number, share: number, tint: Rgb): void {
  const columns = Math.floor(width / DOT_PITCH);
  const span = DOT_PITCH * (DOT_ROWS - 1);
  const top = (CAPSULE_HEIGHT - span - DOT_SIZE) / 2;
  const radius = span / 2 + DOT_SIZE / 2;
  const litEdge = share * width;
  const [dimmed, lit] = [new Path2D(), new Path2D()];
  for (let column = 0; column < columns; column++) {
    const x = column * DOT_PITCH;
    for (let row = 0; row < DOT_ROWS; row++) {
      const y = top + row * DOT_PITCH;
      const dx = Math.max(0, radius - x - DOT_SIZE / 2, x + DOT_SIZE / 2 - (width - radius));
      const dy = y + DOT_SIZE / 2 - CAPSULE_HEIGHT / 2;
      if (dx * dx + dy * dy > radius * radius + 0.5) continue;
      const target = x + DOT_SIZE / 2 <= litEdge ? lit : dimmed;
      target.moveTo(x + DOT_SIZE, y + DOT_SIZE / 2);
      target.arc(x + DOT_SIZE / 2, y + DOT_SIZE / 2, DOT_SIZE / 2, 0, FULL_TURN);
    }
  }
  context.fillStyle = rgba(WHITE, 0.13);
  context.fill(dimmed);
  context.fillStyle = rgba(tint, 1);
  context.fill(lit);
}

function drawSegments(context: CanvasRenderingContext2D, width: number, share: number, tint: Rgb): void {
  stadium(context, 0.5, 0.5, width - 1, CAPSULE_HEIGHT - 1);
  context.strokeStyle = rgba(WHITE, 0.4);
  context.lineWidth = 1;
  context.stroke();
  const innerX = 0.5 + INSET + 1;
  const innerY = innerX;
  const innerWidth = width - 1 - 2 * (INSET + 1);
  const innerHeight = CAPSULE_HEIGHT - 1 - 2 * (INSET + 1);
  const count = Math.floor((innerWidth + SEGMENT_PITCH - SEGMENT_WIDTH) / SEGMENT_PITCH);
  const lit = Math.round(share * count);
  const [dimmed, body, head] = [new Path2D(), new Path2D(), new Path2D()];
  for (let index = 0; index < count; index++) {
    const target = index >= lit ? dimmed : index >= lit - BRAND_SEGMENTS ? head : body;
    target.rect(innerX + index * SEGMENT_PITCH, innerY, SEGMENT_WIDTH, innerHeight);
  }
  context.fillStyle = rgba(WHITE, 0.16);
  context.fill(dimmed);
  context.fillStyle = rgba(WHITE, 0.92);
  context.fill(body);
  context.fillStyle = rgba(tint, 1);
  context.fill(head);
}

function drawFlat(context: CanvasRenderingContext2D, width: number, share: number, tint: Rgb): void {
  const [paneWidth, paneHeight] = [width - 1, CAPSULE_HEIGHT - 1];
  stadium(context, 0.5, 0.5, paneWidth, paneHeight);
  context.fillStyle = rgba(WHITE, 0.06);
  context.fill();
  const [innerX, innerY] = [0.5 + INSET, 0.5 + INSET];
  const [innerWidth, innerHeight] = [paneWidth - 2 * INSET, paneHeight - 2 * INSET];
  if (share > 0) {
    const fill = Math.max(innerHeight, innerWidth * share);
    stadium(context, innerX, innerY, fill, innerHeight);
    context.fillStyle = rgba(tint, 1);
    context.fill();
    const radius = (innerHeight * HEAD_SHARE) / 2;
    context.beginPath();
    context.arc(innerX + fill - innerHeight / 2, innerY + innerHeight / 2, radius, 0, FULL_TURN);
    context.fillStyle = rgba(WHITE, 1);
    context.fill();
  }
  stadium(context, 0.5, 0.5, paneWidth, paneHeight);
  context.strokeStyle = rgba(WHITE, 0.18);
  context.lineWidth = 0.8;
  context.stroke();
}
