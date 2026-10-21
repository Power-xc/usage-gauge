import { prepareCanvas } from "./canvas";
import { Glide } from "./glide";
import { WHITE, rgba, type Rgb } from "./theme";

const BREATH_CYCLE_SECONDS = 3.2;
const TRACK_ALPHA = 0.1;
const HEAD_SCALE = 1.7;
const DIMMEST_HEAD = 0.7;
const FULL_TURN = 2 * Math.PI;

/**
 * Remaining share as a solid bar in the tool's colour over a solid track, ending in a white head
 * dot that breathes slowly. The bar is `thickness` tall and centred in a taller canvas so the head,
 * which is a little larger than the bar, has room.
 */
export class CometBar {
  readonly canvas = document.createElement("canvas");
  private readonly context: CanvasRenderingContext2D;
  private readonly width: number;
  private readonly height: number;
  private readonly thickness: number;
  private readonly share = new Glide();
  readonly glides = [this.share];
  private color: Rgb = WHITE;

  constructor(width: number, thickness: number) {
    this.width = width;
    this.thickness = thickness;
    this.height = thickness * 3;
    this.context = prepareCanvas(this.canvas, width, this.height);
    // The extra height is only room for the head; it must not push the layout apart.
    this.canvas.style.margin = `${-thickness}px 0`;
  }

  update(remainingPercent: number, color: Rgb): void {
    this.share.to(Math.min(100, Math.max(0, remainingPercent)) / 100);
    this.color = color;
  }

  draw(seconds: number): void {
    const { context, width, height, thickness } = this;
    const top = (height - thickness) / 2;
    context.clearRect(0, 0, width, height);
    context.fillStyle = rgba(WHITE, TRACK_ALPHA);
    context.beginPath();
    context.roundRect(0, top, width, thickness, thickness / 2);
    context.fill();
    const share = this.share.value;
    if (share <= 0) return;

    const length = Math.max(thickness * 2, width * share);
    context.fillStyle = rgba(this.color, 1);
    context.beginPath();
    context.roundRect(0, top, length, thickness, thickness / 2);
    context.fill();

    const breath = 0.5 + 0.5 * Math.sin((seconds * FULL_TURN) / BREATH_CYCLE_SECONDS);
    const radius = (thickness * HEAD_SCALE) / 2;
    context.fillStyle = rgba(WHITE, DIMMEST_HEAD + (1 - DIMMEST_HEAD) * breath);
    context.beginPath();
    context.arc(length - radius, height / 2, radius, 0, FULL_TURN);
    context.fill();
  }
}
