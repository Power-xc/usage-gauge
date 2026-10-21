import type { UsageLevel } from "./types";

export type Rgb = readonly [number, number, number];

export const rgba = ([r, g, b]: Rgb, alpha: number): string => `rgba(${r}, ${g}, ${b}, ${alpha})`;

export const WHITE: Rgb = [255, 255, 255];
export const BLACK: Rgb = [0, 0, 0];

/** Layout tokens shared by the canvases and the stylesheet (see `style.css`). */
export const DIAL_SIZE = 72;
export const DETAIL_WIDTH = 140;
export const OPACITY_RANGE = { min: 0.3, max: 1 } as const;

const ACCENT: Rgb = [201, 182, 255];
const WARNING: Rgb = [255, 206, 122];
const CRITICAL: Rgb = [255, 128, 128];

/** Signature colour of each tool; unknown providers fall back to the accent. */
export function brand(providerId: string): Rgb {
  switch (providerId) {
    case "claude":
      return [217, 119, 87];
    case "codex":
    case "openai":
      return [16, 163, 127];
    case "gemini":
    case "antigravity":
      return [78, 134, 248];
    case "copilot":
      return [140, 108, 245];
    case "cursor":
      return [214, 218, 228];
    default:
      return ACCENT;
  }
}

/** Warning colour once a window runs low, null while comfortable. Tints the figures only. */
export function alert(level: UsageLevel): Rgb | null {
  if (level === "low") return WARNING;
  if (level === "critical") return CRITICAL;
  return null;
}
