import { hoverLine } from "./clock";
import { el } from "./dom";
import type { ProviderView } from "./types";

/** Cells narrower than this get the short wording of `hoverLine`. */
const FULL_LINE_WIDTH = 200;

export interface RevealOptions {
  /** Where the line sits in the room of the caption it replaces. */
  align?: "leading" | "center" | "trailing";
  /** The cell's width; a narrower one always gets the short wording. */
  width?: number;
  /** Always the short wording, for a caption slot narrower than the cell. */
  isCompact?: boolean;
}

/**
 * A caption that gives way to the tool's reset and measuring times while its cell is hovered, in
 * the same place, so the line never lands on a bar, a rule or the next row (see `style.css`). A
 * tool that is not connected has no times to show. `caption` may be null for an empty slot, such
 * as a plan tag the tool does not have.
 */
export function revealingCaption(provider: ProviderView, caption: HTMLElement | null, options: RevealOptions = {}): HTMLElement {
  const slot = el("div", `reveal-slot ${options.align ?? "leading"}`, caption ?? el("span", "plan", " "));
  if (provider.message !== null) return slot;
  const isCompact = options.isCompact === true || (options.width ?? Infinity) < FULL_LINE_WIDTH;
  slot.append(el("span", "reveal", hoverLine(provider, isCompact)));
  return slot;
}
