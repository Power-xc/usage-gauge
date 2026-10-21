import { prepareCanvas } from "./canvas";
import { WHITE, rgba, type Rgb } from "./theme";

const PITCH = 3.6;
const DOT = 1.9;
const ROWS = 2;
const FULL_TURN = 2 * Math.PI;

/** The long window as a two-row strip of dots: lit for the remaining share, the leading column in the tool's colour. */
export class DotBar {
  readonly canvas = document.createElement("canvas");
  private readonly context: CanvasRenderingContext2D;
  private readonly width: number;
  private readonly height = PITCH * (ROWS - 1) + DOT;
  private remainingShare = 0;
  private color: Rgb = WHITE;

  constructor(width: number) {
    this.width = width;
    this.context = prepareCanvas(this.canvas, width, this.height);
  }

  update(remainingPercent: number, color: Rgb): void {
    this.remainingShare = Math.min(100, Math.max(0, remainingPercent)) / 100;
    this.color = color;
  }

  draw(): void {
    const columns = Math.floor(this.width / PITCH);
    const lit = Math.round(this.remainingShare * columns);
    const [dim, bright, head] = [new Path2D(), new Path2D(), new Path2D()];
    for (let column = 0; column < columns; column++) {
      const target = column >= lit ? dim : column === lit - 1 ? head : bright;
      for (let row = 0; row < ROWS; row++) {
        const x = column * PITCH + DOT / 2;
        const y = row * PITCH + DOT / 2;
        target.moveTo(x + DOT / 2, y);
        target.arc(x, y, DOT / 2, 0, FULL_TURN);
      }
    }
    this.context.clearRect(0, 0, this.width, this.height);
    this.fill(dim, rgba(WHITE, 0.13));
    this.fill(bright, rgba(WHITE, 0.88));
    this.fill(head, rgba(this.color, 1));
  }

  private fill(path: Path2D, style: string): void {
    this.context.fillStyle = style;
    this.context.fill(path);
  }
}
