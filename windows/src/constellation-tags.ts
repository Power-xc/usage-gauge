import { dotMatrixText } from "./dot-matrix";
import { el } from "./dom";
import { REACH, TAG_HEIGHT, type TagPlacement } from "./layouts/tag-layout";
import { WHITE, alert, rgba, type Rgb } from "./theme";
import type { PanelStyle, ProviderView, WindowView } from "./types";

const FIGURE_PITCH = 1.2;
const NO_READING = "–";

/**
 * One tool's tag next to its marker: its name and both shares ("CLAUDE 94 · 37"). In the mono
 * style a 1 px outlined box, in dot bare dot-matrix figures knocked out of the card, in iris a flat
 * chip. `width` is the room reserved for it; the tag itself is as wide as its content.
 */
export function constellationTag(provider: ProviderView, tint: Rgb, style: PanelStyle, width: number): HTMLElement {
  const isDot = style === "dot";
  const title = el("span", "tag-title", style === "iris" ? provider.title : provider.title.toUpperCase());
  const parts = [title, figure(provider.session, "tag-short", isDot), el("span", "tag-sep", "·"), figure(provider.weekly, "tag-long", isDot)];
  const tag = el("span", "constellation-tag", ...parts);
  if (style === "mono") tag.style.borderColor = rgba(tint, 0.85);
  const slot = el("div", "tag-slot", tag);
  slot.style.width = `${width}px`;
  slot.style.height = `${TAG_HEIGHT}px`;
  return slot;
}

function figure(window: WindowView | null, kind: string, isDot: boolean): HTMLElement {
  const text = window ? String(window.displayPercent) : NO_READING;
  const warning = window ? alert(window.level) : null;
  if (isDot) {
    const fallback = rgba(WHITE, kind === "tag-short" ? 1 : 0.62);
    const color = warning ? rgba(warning, 1) : fallback;
    return el("span", `tag-figure ${kind}`, dotMatrixText(text, FIGURE_PITCH, color));
  }
  const node = el("span", `tag-figure ${kind}`, text);
  if (warning) node.style.color = rgba(warning, 1);
  return node;
}

/** An estimate of the tag's width, enough to keep neighbouring tags apart. */
export function tagWidth(provider: ProviderView, style: PanelStyle): number {
  const digits = [provider.session, provider.weekly].map((window) => (window ? String(window.displayPercent).length : 1));
  const total = digits.reduce((sum, count) => sum + count, 0);
  const titleLength = provider.title.length;
  switch (style) {
    case "mono":
      return titleLength * 6 + total * 5.4 + 3 * 5 + 5.4 + 12;
    case "dot":
      return titleLength * 6.1 + digits.reduce((sum, count) => sum + count * 6 - 1, 0) * FIGURE_PITCH + 3 * 5 + 5.4 + 8;
    case "iris":
      return titleLength * 6.4 + total * 6 + 3 * 5 + 4 + 16;
  }
}

/** Top-left of a tag's slot in the field, from its node: beside the marker, shifted by the placement. */
export function tagOrigin(point: { x: number; y: number }, width: number, placement: TagPlacement): { x: number; y: number } {
  const x = placement.side === "right" ? point.x + REACH : point.x - REACH - width;
  return { x, y: point.y + placement.offset - TAG_HEIGHT / 2 };
}
