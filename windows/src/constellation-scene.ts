import type { Drawable } from "./animation";
import type { Point } from "./canvas";
import { drawField, drawNode, type FieldStar } from "./constellation-field";
import { FRAME } from "./constellation-plot";
import { tagOrigin } from "./constellation-tags";
import { GlideSet } from "./glide-set";
import type { PanelStyle } from "./types";

/** Side of the square around a marker that takes the pointer. */
export const MARKER_HIT_SIZE = 18;
/** Numbers a star owns: its position, then its place an hour ago. */
const VALUES_PER_STAR = 4;

/** What the scene moves for one tool: its drawing data, its node's canvas and the elements that follow it. */
export interface SceneStar {
  star: FieldStar;
  tagWidth: number;
  nodeContext: CanvasRenderingContext2D;
  tag: HTMLElement;
  hit: HTMLElement;
}

/**
 * The constellation as one animated thing: the field's canvas, one canvas per node and the tags
 * and pointer targets above them. Positions glide to new readings together, and the scene repaints
 * only when one has moved. A tag keeps the side it was given for the new reading while it glides.
 */
export class ConstellationScene implements Drawable {
  readonly glides: GlideSet["glides"];
  private readonly values: GlideSet;
  private drawn: string | null = null;

  constructor(
    private readonly style: PanelStyle,
    private readonly fieldContext: CanvasRenderingContext2D,
    private readonly stars: SceneStar[],
  ) {
    this.values = new GlideSet(stars.flatMap(({ star }) => [star.point.x, star.point.y, star.past?.x ?? null, star.past?.y ?? null]));
    this.glides = this.values.glides;
  }

  draw(): void {
    const values = this.values.values;
    const key = values.join(",");
    if (key === this.drawn) return;
    this.drawn = key;
    const current = this.stars.map(({ star }, index) => this.current(star, values.slice(index * VALUES_PER_STAR)));
    this.fieldContext.clearRect(0, 0, FRAME.width, FRAME.height);
    drawField(this.fieldContext, this.style, current);
    this.stars.forEach((scene, index) => {
      scene.nodeContext.clearRect(0, 0, FRAME.width, FRAME.height);
      drawNode(scene.nodeContext, this.style, current[index]);
      const origin = tagOrigin(current[index].point, scene.tagWidth, scene.star.placement);
      move(scene.tag, origin, 0);
      move(scene.hit, current[index].point, MARKER_HIT_SIZE / 2);
    });
  }

  private current(star: FieldStar, [x, y, pastX, pastY]: (number | null)[]): FieldStar {
    const past: Point | null = pastX !== null && pastY !== null ? { x: pastX, y: pastY } : null;
    return { ...star, point: { x: x ?? star.point.x, y: y ?? star.point.y }, past };
  }
}

function move(element: HTMLElement, at: Point, inset: number): void {
  element.style.left = `${at.x - inset}px`;
  element.style.top = `${at.y - inset}px`;
}
