import type { Drawable } from "../animation";
import type { ProviderView } from "../types";

/** What a layout produces: the element for the panel body and the canvases it animates. */
export interface LayoutContent {
  element: HTMLElement;
  drawables: Drawable[];
}

/** Builds one tool's block, `width` wide (the room left for its content), pushing its canvases to `drawables`. */
export type BlockBuilder = (provider: ProviderView, index: number, width: number, drawables: Drawable[]) => HTMLElement;
