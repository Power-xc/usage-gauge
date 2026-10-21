import { pointAt, prepareCanvas, type Point } from "./canvas";
import { WHITE, rgba, type Rgb } from "./theme";

const TICKS_PER_POINT = 1.25;
const MIN_TICKS = 24;
const INNER_RADIUS = 0.72;
const OUTER_RADIUS = 0.98;
const CLOCK_RADIUS = 0.6;
/** Length of an unlit tick, as a share of the full tick. */
const DIM_REACH = 0.55;
/** How much shorter the oldest lit tick is than the leading one, as in a loading spinner. */
const TAPER = 0.45;
const BREATH_RATE = 3;
const TWELVE_OCLOCK = -Math.PI / 2;
const FULL_TURN = 2 * Math.PI;
const TIME_WRAP_SECONDS = 3600;

/**
 * Dial in the terminal style: a ring of radial ticks lit for the remaining share, lengthening
 * towards the leading tick, which carries the tool's colour and breathes. A thin inner circle is
 * the clock: the elapsed part of the window drawn bright from 12 o'clock.
 */
export class TickDial {
  readonly canvas = document.createElement("canvas");
  private readonly context: CanvasRenderingContext2D;
  private readonly size: number;
  private remainingShare = 0;
  private elapsed: number | null = null;
  private color: Rgb = WHITE;

  constructor(size: number) {
    this.size = size;
    this.context = prepareCanvas(this.canvas, size, size);
  }

  /** `elapsedFraction` is 0...1, how much of the window has passed; null hides the clock. */
  update(remainingPercent: number, elapsedFraction: number | null, color: Rgb): void {
    this.remainingShare = Math.min(100, Math.max(0, remainingPercent)) / 100;
    this.elapsed = elapsedFraction === null ? null : Math.min(1, Math.max(0, elapsedFraction));
    this.color = color;
  }

  draw(seconds: number): void {
    const { context } = this;
    const time = seconds % TIME_WRAP_SECONDS;
    const center = { x: this.size / 2, y: this.size / 2 };
    const outer = this.size / 2;
    const ticks = Math.max(MIN_TICKS, Math.floor((outer * TICKS_PER_POINT) / 4) * 4);
    const lit = Math.round(this.remainingShare * ticks);
    const width = Math.max(1, outer * 0.035);
    const [dim, bright, head] = [new Path2D(), new Path2D(), new Path2D()];
    const span = OUTER_RADIUS - INNER_RADIUS;
    for (let tick = 0; tick < ticks; tick++) {
      const angle = (tick / ticks) * FULL_TURN + TWELVE_OCLOCK;
      const reach = tick < lit ? 1 - (TAPER * (lit - 1 - tick)) / Math.max(1, lit) : DIM_REACH;
      const target = tick >= lit ? dim : tick === lit - 1 ? head : bright;
      const from = pointAt(center, outer * INNER_RADIUS, angle);
      const to = pointAt(center, outer * (INNER_RADIUS + span * reach), angle);
      target.moveTo(from.x, from.y);
      target.lineTo(to.x, to.y);
    }
    context.clearRect(0, 0, this.size, this.size);
    this.stroke(dim, rgba(WHITE, 0.14), width);
    this.stroke(bright, rgba(WHITE, 0.92), width);
    context.globalAlpha = 0.75 + 0.25 * Math.sin(time * BREATH_RATE);
    this.stroke(head, rgba(this.color, 1), width * 1.6);
    context.globalAlpha = 1;
    this.drawClock(center, outer * CLOCK_RADIUS, width);
  }

  private drawClock(center: Point, radius: number, width: number): void {
    const circle = new Path2D();
    circle.arc(center.x, center.y, radius, 0, FULL_TURN);
    this.stroke(circle, rgba(WHITE, 0.16), width * 0.7);
    if (this.elapsed === null || this.elapsed <= 0) return;
    const passed = new Path2D();
    passed.arc(center.x, center.y, radius, TWELVE_OCLOCK, TWELVE_OCLOCK + FULL_TURN * this.elapsed);
    this.stroke(passed, rgba(WHITE, 0.75), width);
  }

  private stroke(path: Path2D, style: string, width: number): void {
    this.context.strokeStyle = style;
    this.context.lineWidth = width;
    this.context.stroke(path);
  }
}
