import type { Drawable } from "../animation";
import { hoverLine } from "../clock";
import { prepareCanvas } from "../canvas";
import { CAPTION_Y, type FieldStar } from "../constellation-field";
import { FIELD, FRAME, PLOT_HEIGHT, plotPoint } from "../constellation-plot";
import { ConstellationScene, MARKER_HIT_SIZE, type SceneStar } from "../constellation-scene";
import { starsOf } from "../constellation-star";
import { constellationTag, tagWidth } from "../constellation-tags";
import { el } from "../dom";
import { brand } from "../theme";
import type { PanelStyle, ProviderView } from "../types";
import { singleCell } from "./grid";
import { placeTags } from "./tag-layout";
import type { LayoutContent } from "./types";

const MAX_TOOLS = 8;
/** Width and height of the line under the field. */
const FOOTNOTE = { width: 220, height: 12 };

/**
 * One chart for every tool: a field where a tool's short-window share runs left to right and its
 * long-window share bottom to top, each tool a node with a tag, linked into a constellation in
 * order of short-window share. Where the history reaches back, a faded trail shows where each
 * tool stood an hour ago. A tool is its node and tag together: pointing at either focuses it
 * (the line under the field then gives its times) and clicking opens it.
 */
export function buildConstellationLayout(providers: ProviderView[], style: PanelStyle): LayoutContent {
  const stars = starsOf(providers).slice(0, MAX_TOOLS);
  const unavailable = providers.filter((provider) => provider.message !== null);
  const points = stars.map((star) => plotPoint(star.position));
  const widths = stars.map((star) => tagWidth(star.provider, style));
  const bounds = { minX: 0, maxX: FRAME.width, maxY: PLOT_HEIGHT };
  const placements = placeTags(points, widths, bounds);

  const fieldCanvas = document.createElement("canvas");
  const fieldContext = prepareCanvas(fieldCanvas, FRAME.width, FRAME.height);
  const nodes = stars.map((star, index): { scene: SceneStar; element: HTMLElement } => {
    const tint = brand(star.provider.id);
    const fieldStar: FieldStar = { tint, point: points[index], past: star.before ? plotPoint(star.before) : null, placement: placements[index] };
    const canvas = document.createElement("canvas");
    const tag = constellationTag(star.provider, tint, style, widths[index]);
    tag.classList.add(placements[index].side);
    const hit = el("div", "node-hit");
    hit.style.width = hit.style.height = `${MARKER_HIT_SIZE}px`;
    const element = el("div", "constellation-node", canvas, hit, tag);
    element.dataset.tool = star.provider.id;
    return { scene: { star: fieldStar, tagWidth: widths[index], nodeContext: prepareCanvas(canvas, FRAME.width, FRAME.height), tag, hit }, element };
  });

  const scene = new ConstellationScene(style, fieldContext, nodes.map((node) => node.scene));
  const drawables: Drawable[] = [scene];
  const field = el("div", "constellation", fieldCanvas, ...nodes.map((node) => node.element), footnote(unavailable, stars, style));
  field.style.width = `${FRAME.width}px`;
  field.style.height = `${FRAME.height}px`;
  return { element: singleCell(field, style).element, drawables };
}

/**
 * Under the field: the tools that report nothing and so cannot be placed, or the focused tool's
 * reset and measuring times while one is pointed at.
 */
function footnote(unavailable: ProviderView[], stars: { provider: ProviderView }[], style: PanelStyle): HTMLElement {
  const line = el("div", "constellation-footnote");
  line.style.left = `${FIELD.left}px`;
  line.style.top = `${FIELD.bottom + CAPTION_Y - FOOTNOTE.height / 2}px`;
  line.style.width = `${FOOTNOTE.width}px`;
  line.style.height = `${FOOTNOTE.height}px`;
  if (unavailable.length > 0 || stars.length === 0) {
    const names = unavailable.map((provider) => (style === "iris" ? provider.title : provider.title.toUpperCase()));
    line.append(el("span", "footnote-text", `연결 안 됨 · ${names.join(", ")}`));
  }
  for (const { provider } of stars) {
    const times = el("span", "footnote-time", hoverLine(provider));
    times.dataset.follows = provider.id;
    line.append(times);
  }
  return line;
}
