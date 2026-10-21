import { noise, pointAt, prepareCanvas, type Point } from "./canvas";
import { Glide } from "./glide";
import { WHITE, rgba, type Rgb } from "./theme";

/** Radial dot columns per point of radius, rounded to whole quarters of the ring. */
const COLUMNS_PER_POINT = 1.4;
const COLUMN_RADII = [0.78, 0.87, 0.96];
const CLOCK_RADIUS = 0.64;
const CLOCK_DOTS_PER_POINT = 1.1;
const MIN_DOTS = 24;
const TWELVE_OCLOCK = -Math.PI / 2;
const FULL_TURN = 2 * Math.PI;
const TIME_WRAP_SECONDS = 3600;
/** Share of the lit dots that dim at any moment, so the ring twinkles like an LED panel. */
const TWINKLE_CUTOFF = 0.86;

/**
 * Dial in the dot-matrix style: a ring of radial dot columns lit for the remaining share, its
 * outer dots and leading column in the tool's colour, and an inner dotted circle that doubles as
 * the clock — the elapsed part of the window lit, a dot in the tool's colour at now.
 */
export class DotDial {
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

  /** `elapsedFraction` is 0...1, how much of the window has passed; null hides the clock. */
  update(remainingPercent: number, elapsedFraction: number | null, color: Rgb): void {
    this.share.to(Math.min(100, Math.max(0, remainingPercent)) / 100);
    this.elapsed = elapsedFraction === null ? null : Math.min(1, Math.max(0, elapsedFraction));
    this.color = color;
  }

  private get remainingShare(): number {
    return this.share.value;
  }

  draw(seconds: number): void {
    const time = seconds % TIME_WRAP_SECONDS;
    const center = { x: this.size / 2, y: this.size / 2 };
    const outer = this.size / 2;
    const dot = Math.max(1, outer * 0.052);
    this.context.clearRect(0, 0, this.size, this.size);
    this.drawColumns(center, outer, dot, time);
    this.drawClock(center, outer * CLOCK_RADIUS, outer, dot);
  }

  private drawColumns(center: Point, outer: number, dot: number, time: number): void {
    const columns = Math.max(MIN_DOTS, Math.floor((outer * COLUMNS_PER_POINT) / 4) * 4);
    const litColumns = Math.round(this.remainingShare * columns);
    const [dim, lit, tinted, twinkle] = [new Path2D(), new Path2D(), new Path2D(), new Path2D()];
    const step = Math.floor(time * 3);
    for (let column = 0; column < columns; column++) {
      const angle = (column / columns) * FULL_TURN + TWELVE_OCLOCK;
      const isLit = column < litColumns;
      const isHead = isLit && column === litColumns - 1;
      COLUMN_RADII.forEach((radius, row) => {
        const spot = pointAt(center, outer * radius, angle);
        let target = lit;
        if (!isLit) target = dim;
        else if (isHead || row === COLUMN_RADII.length - 1) target = tinted;
        else if (noise(column * 3 + row + step) > TWINKLE_CUTOFF) target = twinkle;
        addDot(target, spot, dot);
      });
    }
    this.fill(dim, rgba(WHITE, 0.13));
    this.fill(lit, rgba(WHITE, 0.9));
    this.fill(twinkle, rgba(WHITE, 0.45));
    this.fill(tinted, rgba(this.color, 1));
  }

  /** Dotted inner circle: elapsed dots lit from 12 o'clock, the rest faint, a larger one at now. */
  private drawClock(center: Point, radius: number, outer: number, dot: number): void {
    const count = Math.max(MIN_DOTS, Math.floor((outer * CLOCK_DOTS_PER_POINT) / 4) * 4);
    const [passed, ahead] = [new Path2D(), new Path2D()];
    for (let index = 0; index < count; index++) {
      const share = index / count;
      const spot = pointAt(center, radius, share * FULL_TURN + TWELVE_OCLOCK);
      addDot(this.elapsed !== null && share < this.elapsed ? passed : ahead, spot, dot * 0.8);
    }
    this.fill(ahead, rgba(WHITE, 0.18));
    this.fill(passed, rgba(WHITE, 0.7));
    if (this.elapsed === null) return;
    const now = new Path2D();
    addDot(now, pointAt(center, radius, this.elapsed * FULL_TURN + TWELVE_OCLOCK), dot * 2.1);
    this.fill(now, rgba(this.color, 1));
  }

  private fill(path: Path2D, style: string): void {
    this.context.fillStyle = style;
    this.context.fill(path);
  }
}

/** Adds a dot of the given diameter centred on `spot`. */
function addDot(path: Path2D, spot: Point, diameter: number): void {
  const radius = diameter / 2;
  path.moveTo(spot.x + radius, spot.y);
  path.arc(spot.x, spot.y, radius, 0, FULL_TURN);
}
