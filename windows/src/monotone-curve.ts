import type { Point } from "./canvas";

const SAMPLING_STEP = 0.5;

/**
 * A smooth curve through points of increasing x that never leaves the range of its neighbours:
 * a monotone cubic (Fritsch–Butland tangents), so a line chart of a share stays between 0 and
 * 100 and shows no overshoot where the data turns flat.
 */
export class MonotoneCurve {
  private readonly points: Point[] = [];
  private readonly slopes: number[];

  constructor(source: Point[]) {
    for (const point of source) {
      const last = this.points[this.points.length - 1];
      if (!last || point.x > last.x) this.points.push(point);
      else if (point.x === last.x) this.points[this.points.length - 1] = point;
    }
    this.slopes = tangents(this.points);
  }

  get start(): Point | undefined {
    return this.points[0];
  }

  get end(): Point | undefined {
    return this.points[this.points.length - 1];
  }

  /** The curve as an open path; empty without points. */
  path(): Path2D {
    const path = new Path2D();
    const [first] = this.points;
    if (!first) return path;
    path.moveTo(first.x, first.y);
    for (let index = 0; index < this.points.length - 1; index++) {
      const [a, b] = [this.points[index], this.points[index + 1]];
      const third = (b.x - a.x) / 3;
      path.bezierCurveTo(a.x + third, a.y + this.slopes[index] * third, b.x - third, b.y - this.slopes[index + 1] * third, b.x, b.y);
    }
    return path;
  }

  /** The curve closed down to `baseline`: the area under a line. */
  area(baseline: number): Path2D {
    const area = this.path();
    const [first, last] = [this.start, this.end];
    if (!first || !last) return area;
    area.lineTo(last.x, baseline);
    area.lineTo(first.x, baseline);
    area.closePath();
    return area;
  }

  /** Height of the curve at `x`, which must lie between its ends. */
  yAt(x: number): number {
    let index = -1;
    for (let candidate = 0; candidate < this.points.length - 1; candidate++) if (this.points[candidate].x <= x) index = candidate;
    if (index < 0) return this.points[0]?.y ?? 0;
    const [a, b] = [this.points[index], this.points[index + 1]];
    const width = b.x - a.x;
    const t = Math.min(1, Math.max(0, (x - a.x) / width));
    const [t2, t3] = [t * t, t * t * t];
    return (
      (2 * t3 - 3 * t2 + 1) * a.y +
      (t3 - 2 * t2 + t) * width * this.slopes[index] +
      (-2 * t3 + 3 * t2) * b.y +
      (t3 - t2) * width * this.slopes[index + 1]
    );
  }

  /** Points along the curve `spacing` apart measured on the curve itself, from its start. */
  evenlySpaced(spacing: number): Point[] {
    const [first, last] = [this.start, this.end];
    if (!first || !last) return [];
    const spaced = [first];
    let previous = first;
    let travelled = 0;
    for (let x = first.x + SAMPLING_STEP; x <= last.x; x += SAMPLING_STEP) {
      const current = { x, y: this.yAt(x) };
      travelled += Math.hypot(current.x - previous.x, current.y - previous.y);
      if (travelled >= spacing) {
        spaced.push(current);
        travelled = 0;
      }
      previous = current;
    }
    return spaced;
  }
}

/** Tangent slopes that keep each piece monotone: zero at turning points, a weighted harmonic mean of the neighbouring secants elsewhere. */
function tangents(points: Point[]): number[] {
  if (points.length < 2) return points.map(() => 0);
  const widths = points.slice(1).map((point, index) => point.x - points[index].x);
  const secants = points.slice(1).map((point, index) => (point.y - points[index].y) / widths[index]);
  const slopes = [secants[0]];
  for (let index = 1; index < points.length - 1; index++) {
    const [before, after] = [secants[index - 1], secants[index]];
    if (before * after <= 0) {
      slopes.push(0);
      continue;
    }
    const [widthBefore, widthAfter] = [widths[index - 1], widths[index]];
    slopes.push((3 * (widthBefore + widthAfter)) / ((2 * widthAfter + widthBefore) / before + (widthAfter + 2 * widthBefore) / after));
  }
  slopes.push(secants[secants.length - 1]);
  return slopes;
}
