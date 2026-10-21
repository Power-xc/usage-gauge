import { prepareCanvas } from "./canvas";
import { Glide } from "./glide";
import { WHITE, rgba, type Rgb } from "./theme";
import type { PanelStyle } from "./types";

const DOT_PITCH = 5.6;
const DOT_DIAMETER = 3.4;
const SEGMENT_PITCH = 5;
const SEGMENT_HEIGHT = 3;
const DIM_ALPHA = 0.14;
const TRACK_ALPHA = 0.1;
const FULL_TURN = 2 * Math.PI;
/** The white head dot of an iris column, as a share of its width. */
const HEAD_SHARE = 0.4;

/**
 * The remaining share as an upright column in the style's voice: a solid fill with a white head
 * dot (iris), dots lit from the bottom (dot) or stacked segments (mono). The tool's colour
 * marks the top of what is left. It glides to a new share like the dials and bars do.
 */
export class VerticalMeter {
  readonly canvas = document.createElement("canvas");
  readonly glides: readonly Glide[];
  private readonly context: CanvasRenderingContext2D;
  private readonly share = new Glide();
  private drawn: number | null = null;

  constructor(
    private readonly style: PanelStyle,
    remainingPercent: number,
    private readonly tint: Rgb,
    private readonly width: number,
    private readonly height: number,
  ) {
    this.glides = [this.share];
    this.share.to(Math.min(100, Math.max(0, remainingPercent)) / 100);
    this.context = prepareCanvas(this.canvas, width, height);
  }

  /** Repaints only when the share has moved since the last paint. */
  draw(): void {
    const share = this.share.value;
    if (share === this.drawn) return;
    this.drawn = share;
    const { context, style, tint, width, height } = this;
    context.clearRect(0, 0, width, height);
    if (style === "iris") drawSolid(context, share, tint, width, height);
    else if (style === "dot") drawDots(context, share, tint, width, height);
    else drawSegments(context, share, tint, width, height);
  }
}

/** A meter drawn once, for callers whose reading never changes. */
export function verticalMeter(style: PanelStyle, remainingPercent: number, tint: Rgb, width: number, height: number): HTMLCanvasElement {
  const meter = new VerticalMeter(style, remainingPercent, tint, width, height);
  meter.draw();
  return meter.canvas;
}

function drawSolid(context: CanvasRenderingContext2D, share: number, tint: Rgb, width: number, height: number): void {
  const radius = width / 2;
  context.fillStyle = rgba(WHITE, TRACK_ALPHA);
  context.beginPath();
  context.roundRect(0, 0, width, height, radius);
  context.fill();
  if (share <= 0) return;

  const fill = Math.max(height * share, width);
  const top = height - fill;
  context.fillStyle = rgba(tint, 1);
  context.beginPath();
  context.roundRect(0, top, width, fill, radius);
  context.fill();

  const head = (width * HEAD_SHARE) / 2;
  context.fillStyle = rgba(WHITE, 1);
  context.beginPath();
  context.arc(radius, top + radius, head, 0, FULL_TURN);
  context.fill();
}

function drawDots(context: CanvasRenderingContext2D, share: number, tint: Rgb, width: number, height: number): void {
  const columns = Math.floor((width + DOT_PITCH - DOT_DIAMETER) / DOT_PITCH);
  const rows = Math.floor((height + DOT_PITCH - DOT_DIAMETER) / DOT_PITCH);
  const inset = (width - ((columns - 1) * DOT_PITCH + DOT_DIAMETER)) / 2;
  const lit = Math.round(share * rows);
  const [dim, bright, head] = [new Path2D(), new Path2D(), new Path2D()];
  for (let row = 0; row < rows; row++) {
    const y = height - DOT_DIAMETER - row * DOT_PITCH + DOT_DIAMETER / 2;
    const target = row >= lit ? dim : row === lit - 1 ? head : bright;
    for (let column = 0; column < columns; column++) {
      const x = inset + column * DOT_PITCH + DOT_DIAMETER / 2;
      target.moveTo(x + DOT_DIAMETER / 2, y);
      target.arc(x, y, DOT_DIAMETER / 2, 0, FULL_TURN);
    }
  }
  fillAll(context, dim, bright, head, tint, 0.9);
}

function drawSegments(context: CanvasRenderingContext2D, share: number, tint: Rgb, width: number, height: number): void {
  const count = Math.floor((height + SEGMENT_PITCH - SEGMENT_HEIGHT) / SEGMENT_PITCH);
  const lit = Math.round(share * count);
  const [dim, bright, head] = [new Path2D(), new Path2D(), new Path2D()];
  for (let index = 0; index < count; index++) {
    const target = index >= lit ? dim : index === lit - 1 ? head : bright;
    target.rect(0, height - SEGMENT_HEIGHT - index * SEGMENT_PITCH, width, SEGMENT_HEIGHT);
  }
  fillAll(context, dim, bright, head, tint, 0.92);
}

function fillAll(context: CanvasRenderingContext2D, dim: Path2D, bright: Path2D, head: Path2D, tint: Rgb, brightAlpha: number): void {
  context.fillStyle = rgba(WHITE, DIM_ALPHA);
  context.fill(dim);
  context.fillStyle = rgba(WHITE, brightAlpha);
  context.fill(bright);
  context.fillStyle = rgba(tint, 1);
  context.fill(head);
}
