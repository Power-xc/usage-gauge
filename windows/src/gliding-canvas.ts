import type { Drawable } from "./animation";
import { prepareCanvas } from "./canvas";
import type { Glide } from "./glide";
import { GlideSet } from "./glide-set";

/** Draws one frame of a chart from its current values, in CSS pixels. */
export type Paint = (context: CanvasRenderingContext2D, values: (number | null)[]) => void;

/**
 * A chart on its own canvas that eases to new readings like the dials and bars do: it repaints
 * only when a value has moved since the last paint, so a still chart costs nothing. `targets` are
 * the values it paints, in a fixed order; a null stays null.
 */
export class GlidingCanvas implements Drawable {
  readonly canvas = document.createElement("canvas");
  readonly glides: readonly Glide[];
  private readonly context: CanvasRenderingContext2D;
  private readonly values: GlideSet;
  private drawn: string | null = null;

  constructor(
    private readonly width: number,
    private readonly height: number,
    targets: readonly (number | null)[],
    private readonly paint: Paint,
  ) {
    this.context = prepareCanvas(this.canvas, width, height);
    this.values = new GlideSet(targets);
    this.glides = this.values.glides;
  }

  draw(): void {
    const values = this.values.values;
    const key = values.join(",");
    if (key === this.drawn) return;
    this.drawn = key;
    this.context.clearRect(0, 0, this.width, this.height);
    this.paint(this.context, values);
  }
}
