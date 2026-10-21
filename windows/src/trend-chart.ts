import { prepareCanvas, type Point } from "./canvas";
import { addDisc, chartFont, fillDisc } from "./chart-draw";
import { MonotoneCurve } from "./monotone-curve";
import { BLACK, WHITE, rgba, type Rgb } from "./theme";
import type { TrendSeries } from "./trend-series";
import type { PanelStyle } from "./types";

export const TREND_HEIGHT = 76;
/** Room for the "100" labels; the footer under the chart starts at the same x. */
export const TREND_AXIS_INSET = 24;

const EDGE_INSET = 6;
const GUIDE_LEVELS = [0, 0.5, 1];
const DASH = [3, 3];
const PROJECTION_ALPHA = 0.55;
const DOT_PITCH = 4;
const NEWEST_DOTS = 8;
const AXIS_FONT_SIZE = 8;
const AXIS_ALPHA = 0.42;
/** Readings closer than this on screen are merged, so the curve flows instead of twitching. */
const MINIMUM_SPACING = 8;
const FLOOR_ALPHA = 0.16;
const GUIDE_ALPHA = 0.07;
const MARKER_RADIUS = 4;
const DOT_MARKER_RADIUS = 5.5;

/**
 * The line chart of one window's remaining share: a smooth curve over its area, with the axis
 * labels at the left. Iris draws a flat coloured curve and area, mono a crisp 1 px line over
 * hairline rules, dot sets the curve and its area in dots. The part after now stays empty except
 * for the faint projection. Without a series only the axis is drawn.
 */
export function trendChart(series: TrendSeries | null, tint: Rgb, style: PanelStyle, width: number): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  const context = prepareCanvas(canvas, width, TREND_HEIGHT);
  const frame = {
    x: TREND_AXIS_INSET,
    y: EDGE_INSET,
    width: width - TREND_AXIS_INSET - EDGE_INSET,
    height: TREND_HEIGHT - 2 * EDGE_INSET,
  };
  const chart = new Chart(context, frame, tint, style, width);
  chart.drawAxis();
  if (series) chart.drawSeries(series);
  return canvas;
}

interface Frame {
  x: number;
  y: number;
  width: number;
  height: number;
}

class Chart {
  constructor(
    private readonly context: CanvasRenderingContext2D,
    private readonly frame: Frame,
    private readonly tint: Rgb,
    private readonly style: PanelStyle,
    private readonly width: number,
  ) {}

  /** "100", "50" and "0" at the left, and the guides they stand for in the mono and dot styles. */
  drawAxis(): void {
    const { context, frame, style, width } = this;
    context.font = chartFont(style, AXIS_FONT_SIZE);
    context.textBaseline = "middle";
    for (const fraction of GUIDE_LEVELS) {
      const y = Math.round(frame.y + frame.height - fraction * frame.height) + 0.5;
      context.fillStyle = rgba(WHITE, AXIS_ALPHA);
      context.fillText(String(Math.round(fraction * 100)), 0, y);
      const alpha = fraction === 0 ? FLOOR_ALPHA : GUIDE_ALPHA;
      context.fillStyle = rgba(WHITE, alpha);
      if (style === "mono") context.fillRect(frame.x, y - 0.5, width - frame.x, 1);
      else if (style === "iris" && fraction === 0) context.fillRect(frame.x, y - 0.5, width - frame.x, 1);
      else if (style === "dot") this.guideDots(y, alpha + 0.05);
    }
  }

  drawSeries(series: TrendSeries): void {
    const curves = series.segments
      .filter((run) => run.length > 1)
      .map((run) => new MonotoneCurve(thinned(run.map((point) => this.place(point)))));
    if (this.style === "dot") this.drawDotted(curves, series);
    else this.drawLine(curves, series);
  }

  private guideDots(y: number, alpha: number): void {
    const dots = new Path2D();
    for (let x = this.frame.x; x <= this.width; x += DOT_PITCH) addDisc(dots, { x, y }, 0.6);
    this.context.fillStyle = rgba(WHITE, alpha);
    this.context.fill(dots);
  }

  private place(point: Point): Point {
    const { frame } = this;
    return { x: frame.x + point.x * frame.width, y: frame.y + frame.height - point.y * frame.height };
  }

  private projection(series: TrendSeries): { head: Point; end: Point } | null {
    return series.projection ? { head: this.place(series.head), end: this.place(series.projection) } : null;
  }

  /** Mono and iris: area, curve, projection and the ringed marker of the latest reading. */
  private drawLine(curves: MonotoneCurve[], series: TrendSeries): void {
    const { context, tint, style, frame } = this;
    const isIris = style === "iris";
    for (const curve of curves) {
      context.fillStyle = rgba(tint, isIris ? 0.16 : 0.07);
      context.fill(curve.area(frame.y + frame.height));
      context.strokeStyle = rgba(tint, 1);
      context.lineWidth = isIris ? 1.8 : 1;
      context.lineJoin = "round";
      context.lineCap = isIris ? "round" : "butt";
      context.stroke(curve.path());
    }
    const start = curves[0]?.start;
    if (start && isIris) fillDisc(context, start, 2.5, rgba(WHITE, 1));
    else if (start) {
      context.fillStyle = rgba(tint, 1);
      context.fillRect(start.x - 2, start.y - 2, 4, 4);
    }
    const projection = this.projection(series);
    if (projection) {
      context.strokeStyle = rgba(tint, PROJECTION_ALPHA);
      context.lineWidth = isIris ? 1.2 : 1;
      context.lineCap = "round";
      context.setLineDash(DASH);
      context.beginPath();
      context.moveTo(projection.head.x, projection.head.y);
      context.lineTo(projection.end.x, projection.end.y);
      context.stroke();
      context.setLineDash([]);
    }
    this.marker(this.place(series.head), MARKER_RADIUS);
  }

  private drawDotted(curves: MonotoneCurve[], series: TrendSeries): void {
    const { context, tint } = this;
    for (const curve of curves) this.fillDots(curve);
    const projection = this.projection(series);
    if (projection) {
      const length = Math.hypot(projection.end.x - projection.head.x, projection.end.y - projection.head.y);
      const steps = Math.floor(length / (2 * DOT_PITCH));
      const dots = new Path2D();
      for (let step = 1; step <= steps; step++) {
        const t = step / steps;
        addDisc(dots, { x: projection.head.x + (projection.end.x - projection.head.x) * t, y: projection.head.y + (projection.end.y - projection.head.y) * t }, 1);
      }
      context.fillStyle = rgba(tint, PROJECTION_ALPHA);
      context.fill(dots);
    }
    const plotted = curves.flatMap((curve) => curve.evenlySpaced(DOT_PITCH));
    const [older, newest] = [new Path2D(), new Path2D()];
    plotted.forEach((point, index) => addDisc(index >= plotted.length - NEWEST_DOTS ? newest : older, point, 1.25));
    context.fillStyle = rgba(WHITE, 0.9);
    context.fill(older);
    context.fillStyle = rgba(tint, 1);
    context.fill(newest);
    this.marker(this.place(series.head), DOT_MARKER_RADIUS);
  }

  /** The area under a curve as faint dots on a lattice, thinning out towards the bottom. */
  private fillDots(curve: MonotoneCurve): void {
    const { frame, context, tint } = this;
    const [first, last] = [curve.start, curve.end];
    if (!first || !last) return;
    const bottom = frame.y + frame.height;
    const firstColumn = Math.ceil((first.x - frame.x) / DOT_PITCH);
    const lastColumn = Math.floor((last.x - frame.x) / DOT_PITCH);
    for (let column = firstColumn; column <= lastColumn; column++) {
      const x = frame.x + column * DOT_PITCH;
      const top = curve.yAt(x);
      for (let y = bottom - DOT_PITCH; y > top + DOT_PITCH / 2; y -= DOT_PITCH) {
        const depth = (y - top) / frame.height;
        fillDisc(context, { x, y }, 0.7, rgba(tint, Math.max(0.05, 0.32 - depth * 0.45)));
      }
    }
  }

  /** Ringed marker of the latest reading. */
  private marker(center: Point, radius: number): void {
    const { context, tint } = this;
    fillDisc(context, center, radius, rgba(BLACK, 0.6));
    const ring = new Path2D();
    ring.arc(center.x, center.y, radius, 0, 2 * Math.PI);
    context.strokeStyle = rgba(tint, 1);
    context.lineWidth = 1.4;
    context.stroke(ring);
    fillDisc(context, center, 1.5, rgba(tint, 1));
  }
}

function thinned(points: Point[]): Point[] {
  const [first, last] = [points[0], points[points.length - 1]];
  if (!first || !last) return points;
  const kept = [first];
  for (const point of points.slice(1)) if (point.x - kept[kept.length - 1].x >= MINIMUM_SPACING) kept.push(point);
  if (kept[kept.length - 1].x < last.x) {
    if (kept.length > 1 && last.x - kept[kept.length - 1].x < MINIMUM_SPACING / 2) kept.pop();
    kept.push(last);
  }
  return kept;
}
