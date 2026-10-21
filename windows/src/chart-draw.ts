import type { Point } from "./canvas";
import type { PanelStyle } from "./types";

const FULL_TURN = 2 * Math.PI;

/** Adds a circle to a path. */
export function addDisc(path: Path2D, center: Point, radius: number): void {
  path.moveTo(center.x + radius, center.y);
  path.arc(center.x, center.y, radius, 0, FULL_TURN);
}

export function fillDisc(context: CanvasRenderingContext2D, center: Point, radius: number, color: string): void {
  const disc = new Path2D();
  addDisc(disc, center, radius);
  context.fillStyle = color;
  context.fill(disc);
}

/** The panel's label face for the style, read from the stylesheet's tokens so canvas text matches the page. */
export function chartFont(style: PanelStyle, size: number, weight = 400): string {
  const tokens = getComputedStyle(document.documentElement);
  const family = tokens.getPropertyValue(style === "iris" ? "--font" : "--font-mono").trim();
  return `${weight} ${size}px ${family}`;
}

/** Index of the last slice that has a value (the one holding now), or -1. */
export function lastValueIndex(values: (number | null)[]): number {
  for (let index = values.length - 1; index >= 0; index--) if (values[index] !== null) return index;
  return -1;
}
