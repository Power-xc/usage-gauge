import { constellationField, type FieldStar } from "../constellation-field";
import { FRAME, PLOT_HEIGHT, plotPoint } from "../constellation-plot";
import { starsOf } from "../constellation-star";
import { constellationTag, tagOrigin, tagWidth } from "../constellation-tags";
import { el } from "../dom";
import { brand } from "../theme";
import type { PanelStyle, ProviderView } from "../types";
import { singleCell } from "./grid";
import { placeTags } from "./tag-layout";
import type { LayoutContent } from "./types";

const MAX_TOOLS = 8;

/**
 * One chart for every tool: a field where a tool's short-window share runs left to right and its
 * long-window share bottom to top, each tool a node with a tag, linked into a constellation in
 * order of short-window share. Where the history reaches back, a faded trail shows where each
 * tool stood an hour ago.
 */
export function buildConstellationLayout(providers: ProviderView[], style: PanelStyle): LayoutContent {
  const stars = starsOf(providers).slice(0, MAX_TOOLS);
  const unavailable = providers.filter((provider) => provider.message !== null);
  const points = stars.map((star) => plotPoint(star.position));
  const widths = stars.map((star) => tagWidth(star.provider, style));
  const bounds = { minX: 0, maxX: FRAME.width, maxY: PLOT_HEIGHT };
  const placements = placeTags(points, widths, bounds);
  const fieldStars: FieldStar[] = stars.map((star, index) => ({
    tint: brand(star.provider.id),
    point: points[index],
    past: star.before ? plotPoint(star.before) : null,
    placement: placements[index],
  }));
  const tags = stars.map((star, index) => {
    const slot = constellationTag(star.provider, fieldStars[index].tint, style, widths[index], placements[index]);
    const origin = tagOrigin(points[index], widths[index], placements[index]);
    slot.style.left = `${origin.x}px`;
    slot.style.top = `${origin.y}px`;
    return slot;
  });
  const field = el("div", "constellation", constellationField(style, fieldStars, footnote(unavailable, stars.length, style)), ...tags);
  field.style.width = `${FRAME.width}px`;
  field.style.height = `${FRAME.height}px`;
  return singleCell(field, style);
}

/** Tools that report nothing cannot be placed; they are named under the field instead. */
function footnote(unavailable: ProviderView[], starCount: number, style: PanelStyle): string | null {
  if (unavailable.length === 0 && starCount > 0) return null;
  const names = unavailable.map((provider) => (style === "iris" ? provider.title : provider.title.toUpperCase()));
  return `연결 안 됨 · ${names.join(", ")}`;
}
