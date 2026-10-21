import { prepareCanvas } from "./canvas";
import { Glide } from "./glide";
import { WHITE, rgba, type Rgb } from "./theme";

const PITCH = 3.2;
const SEGMENT_WIDTH = 1.4;
const HEIGHT = 9;

/** The long window as a row of upright segments: lit for the remaining share, the leading one in the tool's colour. */
export class TickBar {
  readonly canvas = document.createElement("canvas");
  private readonly context: CanvasRenderingContext2D;
  private readonly width: number;
  private readonly share = new Glide();
  readonly glides = [this.share];
  private color: Rgb = WHITE;

  constructor(width: number) {
    this.width = width;
    this.context = prepareCanvas(this.canvas, width, HEIGHT);
  }

  update(remainingPercent: number, color: Rgb): void {
    this.share.to(Math.min(100, Math.max(0, remainingPercent)) / 100);
    this.color = color;
  }

  private get remainingShare(): number {
    return this.share.value;
  }

  draw(): void {
    const count = Math.floor((this.width + PITCH - SEGMENT_WIDTH) / PITCH);
    const lit = Math.round(this.remainingShare * count);
    const [dim, bright, head] = [new Path2D(), new Path2D(), new Path2D()];
    for (let index = 0; index < count; index++) {
      const target = index >= lit ? dim : index === lit - 1 ? head : bright;
      target.rect(index * PITCH, 0, SEGMENT_WIDTH, HEIGHT);
    }
    this.context.clearRect(0, 0, this.width, HEIGHT);
    this.fill(dim, rgba(WHITE, 0.16));
    this.fill(bright, rgba(WHITE, 0.92));
    this.fill(head, rgba(this.color, 1));
  }

  private fill(path: Path2D, style: string): void {
    this.context.fillStyle = style;
    this.context.fill(path);
  }
}
