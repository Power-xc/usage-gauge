import type { Point } from "./canvas";
import { CONTENT_WIDTH } from "./theme";

/** Where the constellation's field sits inside its frame, and how shares map onto it. */
export const PLOT_HEIGHT = 200;
/** Room left of the field for the long window's caption. */
const GUTTER = 28;
const MARGIN = 10;
/** Height of the caption row under the field. */
const CAPTION_HEIGHT = 16;

export const FRAME = { width: CONTENT_WIDTH, height: PLOT_HEIGHT + CAPTION_HEIGHT };
export const FIELD = {
  left: GUTTER,
  top: MARGIN,
  right: CONTENT_WIDTH - MARGIN,
  bottom: PLOT_HEIGHT - MARGIN,
  width: CONTENT_WIDTH - GUTTER - MARGIN,
  height: PLOT_HEIGHT - 2 * MARGIN,
  midX: GUTTER + (CONTENT_WIDTH - GUTTER - MARGIN) / 2,
  midY: MARGIN + (PLOT_HEIGHT - 2 * MARGIN) / 2,
};
export const GUTTER_WIDTH = GUTTER;

/** A unit position (y growing upward) as a point of the frame. */
export const plotPoint = (unit: Point): Point => ({ x: FIELD.left + unit.x * FIELD.width, y: FIELD.bottom - unit.y * FIELD.height });
