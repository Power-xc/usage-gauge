/** Where a node's tag sits: on the side the field has room for, shifted up or down until it clears the other tags and markers. */
export interface TagPlacement {
  side: "left" | "right";
  /** Vertical shift of the tag's centre from its node, in points. */
  offset: number;
}

export interface Bounds {
  minX: number;
  maxX: number;
  maxY: number;
}

interface Obstacle {
  span: [number, number];
  range: [number, number];
}

export const MARKER_SIZE = 7;
/** Length of the short line that ties a tag to its marker. */
const LEADER = 9;
export const TAG_HEIGHT = 17;
/** Free space kept between two tags, and around a marker. */
const GAP = 3;
const MARKER_CLEARANCE = MARKER_SIZE / 2 + GAP;

/** Distance from a node's centre to the near edge of its tag. */
export const REACH = MARKER_SIZE / 2 + LEADER;

interface Node {
  x: number;
  y: number;
}

/**
 * Side and vertical shift for every tag. `points` are the node centres and `widths` the tag
 * widths, both in the field's coordinates; tags stay inside `bounds` where the tools allow. A tag
 * takes the side that needs the smaller shift, the right one when they tie.
 */
export function placeTags(points: Node[], widths: number[], bounds: Bounds): TagPlacement[] {
  const order = points.map((_, index) => index).sort((a, b) => points[a].y - points[b].y);
  const limit = bounds.maxY - TAG_HEIGHT / 2;
  const forward = settle(order, points, widths, bounds, 1, limit);
  const lowest = Math.max(...points.map((point, index) => point.y + forward[index].offset), 0);
  return lowest > limit ? settle([...order].reverse(), points, widths, bounds, -1, limit) : forward;
}

/** Places the tags in `order`, each pushed past whatever it overlaps in `direction` (1 = down). */
function settle(order: number[], points: Node[], widths: number[], bounds: Bounds, direction: 1 | -1, limit: number): TagPlacement[] {
  const placements: TagPlacement[] = points.map(() => ({ side: "right", offset: 0 }));
  const placed: Obstacle[] = [];
  const markers: Obstacle[] = points.map((point) => ({
    span: [point.x - MARKER_CLEARANCE, point.x + MARKER_CLEARANCE],
    range: [point.y - MARKER_CLEARANCE, point.y + MARKER_CLEARANCE],
  }));
  const clearance = GAP + TAG_HEIGHT / 2 + 1;
  for (const index of order) {
    const point = points[index];
    const fits = (side: "left" | "right") =>
      side === "right" ? point.x + REACH + widths[index] <= bounds.maxX : point.x - REACH - widths[index] >= bounds.minX;
    const fitting = (["right", "left"] as const).filter(fits);
    const sides = fitting.length > 0 ? fitting : (["left"] as const);
    let best: { side: "left" | "right"; center: number } | null = null;
    for (const side of sides) {
      const start = side === "right" ? point.x + REACH : point.x - REACH - widths[index];
      const span: [number, number] = [start, start + widths[index]];
      const obstacles = [...markers.filter((_, other) => other !== index), ...placed];
      let center = Math.min(point.y, limit);
      for (let block = findOverlap(obstacles, span, center); block; block = findOverlap(obstacles, span, center)) {
        center = direction > 0 ? block.range[1] + clearance : block.range[0] - clearance;
      }
      if (!best || Math.abs(center - point.y) < Math.abs(best.center - point.y)) best = { side, center };
    }
    if (!best) continue;
    const start = best.side === "right" ? point.x + REACH : point.x - REACH - widths[index];
    placed.push({ span: [start, start + widths[index]], range: [best.center - TAG_HEIGHT / 2, best.center + TAG_HEIGHT / 2] });
    placements[index] = { side: best.side, offset: best.center - point.y };
  }
  return placements;
}

const overlaps = (a: [number, number], b: [number, number]): boolean => a[0] <= b[1] && b[0] <= a[1];

function findOverlap(obstacles: Obstacle[], span: [number, number], center: number): Obstacle | undefined {
  const range: [number, number] = [center - TAG_HEIGHT / 2 - GAP, center + TAG_HEIGHT / 2 + GAP];
  return obstacles.find((obstacle) => overlaps(obstacle.span, span) && overlaps(obstacle.range, range));
}
