import type { Point } from "./canvas";
import type { HistoryView, WindowView } from "./types";

/** Recording gaps longer than this (the app was closed) break the line instead of bridging it. */
const GAP_MS = 20 * 60_000;
const HOUR_MS = 3_600_000;

/**
 * A window's remaining share over its whole period, as unit coordinates for the trend chart: x
 * runs from the window's start to its reset, y from empty (0) to full (1).
 */
export interface TrendSeries {
  /** Runs of connected points, oldest first. */
  segments: Point[][];
  /** The latest reading, at now. */
  head: Point;
  /** Where the burn rate leads from now: the empty point, or the reset when it lasts. */
  projection: Point | null;
  burnRate: number | null;
  projectedEmpty: number | null;
  /** Milliseconds the recorded points cover. */
  recordedSpan: number;
}

/** `null` for a window without a reset time or length. */
export function trendSeries(history: HistoryView, window: WindowView): TrendSeries | null {
  const { periodStart: start, periodEnd: end, now } = history;
  if (start === null || end === null || end <= start) return null;
  const length = end - start;
  const unit = (at: number, remaining: number): Point => ({
    x: Math.min(1, Math.max(0, (at - start) / length)),
    y: remaining / 100,
  });

  const points = history.points.slice();
  const recordedSpan = points.length > 0 ? points[points.length - 1].at - points[0].at : 0;
  if (points.length === 0 || points[points.length - 1].at < now) points.push({ at: now, remaining: window.remainingPercent });
  const segments: Point[][] = [];
  let previous: number | null = null;
  for (const point of points) {
    if (previous !== null && point.at - previous <= GAP_MS) segments[segments.length - 1].push(unit(point.at, point.remaining));
    else segments.push([unit(point.at, point.remaining)]);
    previous = point.at;
  }

  const rate = history.burnRate;
  let projection: Point | null = null;
  if (rate !== null) {
    const target = history.projectedEmpty ?? end;
    const left = Math.max(0, window.remainingPercent - (rate * (target - now)) / HOUR_MS);
    projection = unit(target, left);
  }
  return {
    segments,
    head: unit(now, window.remainingPercent),
    projection,
    burnRate: rate,
    projectedEmpty: history.projectedEmpty,
    recordedSpan,
  };
}
