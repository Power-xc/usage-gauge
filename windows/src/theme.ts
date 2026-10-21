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

/** Deep signature colour of each tool; unknown providers fall back to the accent. */
export function brand(providerId: string): Rgb {
  switch (providerId) {
    case "claude":
      return [193, 95, 60];
    case "codex":
    case "openai":
      return [13, 138, 104];
    case "gemini":
    case "antigravity":
      return [52, 98, 214];
    case "copilot":
      return [112, 78, 226];
    case "cursor":
      return [168, 176, 192];
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
