import { noise, pointAt, prepareCanvas, type Point } from "./canvas";
import { Glide } from "./glide";
import { BLACK, WHITE, rgba, type Rgb } from "./theme";

/** Strands per point of radius, so a small dial stays clear instead of crowded. */
const STRANDS_PER_POINT = 1.6;
const MAX_STRANDS = 300;
const PUPIL_RATIO = 0.6;
const PUPIL_OPACITY = 0.5;
const STRAND_START = 1.09;
const STRAND_REACH = { min: 0.3, max: 0.84 } as const;
const HEAD_REACH = 0.96;
/** Every strand leans a little the same way, like the blades of an aperture. */
const STRAND_LEAN = 0.025;
const RING_RADIUS = 0.965;
const STRAND_WIDTH = 0.8;
const HAIRLINE = 0.8;
const RING_WIDTH = 0.6;
const HEAD_STRANDS = 5;
const BREATH_CYCLE_SECONDS = 3.2;
const RIM_DOT_RADIUS = 1.7;
const TWELVE_OCLOCK = -Math.PI / 2;
const FULL_TURN = 2 * Math.PI;
const TIME_WRAP_SECONDS = 3600;

/**
 * Per-strand length as a share of the strand span, computed once: frames only advance time, never
 * re-roll shapes. Two slow waves with a little noise on top, so neighbours stay related.
 */
const REACHES: number[] = Array.from({ length: MAX_STRANDS }, (_, index) => {
  const share = (index / MAX_STRANDS) * FULL_TURN;
  const wave = 0.5 + 0.25 * Math.sin(share * 5 + 1) + 0.25 * Math.sin(share * 11 + 4);
  const length = 0.6 * wave + 0.4 * noise(index);
  return STRAND_REACH.min + (STRAND_REACH.max - STRAND_REACH.min) * length;
});

/**
 * Dial drawn like an iris: fine radial strands round a dark pupil, one thin ring at the edge. The
 * remaining share is lit — the tool's colour, with a white strand leading at the head — and the
 * rest stays a quiet faint white. Everything is solid: no gradients, no glow. Only the head moves:
 * its strand breathes and the strands just behind it shimmer. The pupil's rim doubles as a clock:
 * it brightens from 12 o'clock as the window runs, with a dot at the current moment.
 */
export class IrisDial {
  readonly canvas = document.createElement("canvas");
  private readonly context: CanvasRenderingContext2D;
  private readonly size: number;
  private readonly share = new Glide();
  readonly glides = [this.share];
  private elapsed: number | null = null;
  private color: Rgb = WHITE;

  constructor(size: number) {
    this.size = size;
    this.context = prepareCanvas(this.canvas, size, size);
  }

  /** `elapsedFraction` is 0...1, how much of the window has passed; null hides the rim clock. */
  update(remainingPercent: number, elapsedFraction: number | null, color: Rgb): void {
    this.share.to(Math.min(100, Math.max(0, remainingPercent)) / 100);
    this.elapsed = elapsedFraction === null ? null : Math.min(1, Math.max(0, elapsedFraction));
    this.color = color;
  }

  draw(seconds: number): void {
    const time = seconds % TIME_WRAP_SECONDS;
    const center = { x: this.size / 2, y: this.size / 2 };
    const outer = this.size / 2;
    const pupil = outer * PUPIL_RATIO;
    const { context } = this;
    context.clearRect(0, 0, this.size, this.size);
    context.fillStyle = rgba(BLACK, PUPIL_OPACITY);
    context.beginPath();
    context.arc(center.x, center.y, pupil, 0, FULL_TURN);
    context.fill();
    this.drawStrands(center, pupil, outer, time);
    this.drawRing(center, outer * RING_RADIUS);
    this.drawRimClock(center, pupil * 0.96);
  }

  /**
   * Strands are grouped into two paths, so a frame is a few strokes. The strands leading the lit
   * run are drawn one by one: white at the head, easing back into the tool's colour.
   */
  private drawStrands(center: Point, pupil: number, outer: number, time: number): void {
    const count = Math.min(REACHES.length, Math.floor(outer * STRANDS_PER_POINT));
    const span = outer * 0.9 - pupil;
    const lit = Math.round(this.share.value * count);
    const breath = 0.5 + 0.5 * Math.sin((time * FULL_TURN) / BREATH_CYCLE_SECONDS);

    const strand = (path: Path2D, index: number, reach: number): void => {
      const angle = (index / count) * FULL_TURN + TWELVE_OCLOCK;
      const from = pointAt(center, pupil * STRAND_START, angle);
      const to = pointAt(center, pupil * STRAND_START + span * reach, angle + STRAND_LEAN);
      path.moveTo(from.x, from.y);
      path.lineTo(to.x, to.y);
    };

    const dim = new Path2D();
    const body = new Path2D();
    for (let index = 0; index < count; index++) {
      if (index >= lit) strand(dim, index, REACHES[index]);
      else if (index < lit - HEAD_STRANDS) strand(body, index, REACHES[index]);
    }
    this.stroke(dim, rgba(WHITE, 0.13), STRAND_WIDTH);
    this.stroke(body, rgba(this.color, 1), STRAND_WIDTH);

    for (let step = 0; step < Math.min(HEAD_STRANDS, lit); step++) {
      const index = lit - 1 - step;
      const head = new Path2D();
      strand(head, index, step === 0 ? HEAD_REACH - 0.06 * (1 - breath) : REACHES[index]);
      this.stroke(head, rgba(this.color, 1), STRAND_WIDTH);
      const shimmer = 0.5 + 0.5 * Math.sin((time * FULL_TURN) / BREATH_CYCLE_SECONDS - step * 0.9);
      const whiteness = step === 0 ? 1 : (1 - step / HEAD_STRANDS) * (0.3 + 0.4 * shimmer);
      this.stroke(head, rgba(WHITE, whiteness), STRAND_WIDTH);
    }
  }

  /** One thin ring at the edge: the remaining share in the tool's colour, the rest faint. */
  private drawRing(center: Point, radius: number): void {
    const { context } = this;
    context.strokeStyle = rgba(WHITE, 0.08);
    context.lineWidth = RING_WIDTH;
    context.beginPath();
    context.arc(center.x, center.y, radius, 0, FULL_TURN);
    context.stroke();
    if (this.share.value <= 0) return;
    context.strokeStyle = rgba(this.color, 0.75);
    context.beginPath();
    context.arc(center.x, center.y, radius, TWELVE_OCLOCK, TWELVE_OCLOCK + FULL_TURN * this.share.value);
    context.stroke();
  }

  /** The pupil's rim as a clock: faint all round, bright from 12 o'clock to now, dot at now. */
  private drawRimClock(center: Point, radius: number): void {
    const { context } = this;
    context.strokeStyle = rgba(WHITE, 0.1);
    context.lineWidth = HAIRLINE;
    context.beginPath();
    context.arc(center.x, center.y, radius, 0, FULL_TURN);
    context.stroke();
    if (this.elapsed === null) return;

    context.strokeStyle = rgba(WHITE, 0.45);
    context.beginPath();
    context.arc(center.x, center.y, radius, TWELVE_OCLOCK, TWELVE_OCLOCK + FULL_TURN * this.elapsed);
    context.stroke();

    const dot = pointAt(center, radius, this.elapsed * FULL_TURN + TWELVE_OCLOCK);
    context.fillStyle = rgba(WHITE, 1);
    context.beginPath();
    context.arc(dot.x, dot.y, RIM_DOT_RADIUS, 0, FULL_TURN);
    context.fill();
  }

  private stroke(path: Path2D, style: string, width: number): void {
    this.context.strokeStyle = style;
    this.context.lineWidth = width;
    this.context.stroke(path);
  }
}
