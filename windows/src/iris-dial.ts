import { noise, pointAt, prepareCanvas, type Point } from "./canvas";
import { BLACK, WHITE, rgba, type Rgb } from "./theme";

/** Densities per point of radius, so a small dial stays clear instead of crowded. */
const FIBRES_PER_POINT = 1.8;
const GRAIN_PER_POINT = 2.2;
const MESH_DOTS_PER_POINT = 1.3;
const PUPIL_RATIO = 0.6;
const MESH_RINGS = 2;
const EDGE_RINGS = [
  { radius: 0.93, dots: 84 },
  { radius: 0.985, dots: 116 },
];
const WARM_WHITE: Rgb = [255, 240, 214];
const PRISM: Rgb[] = [
  [140, 194, 255],
  [255, 158, 199],
  [255, 219, 143],
];
const TWELVE_OCLOCK = -Math.PI / 2;
const FULL_TURN = 2 * Math.PI;
const TIME_WRAP_SECONDS = 3600;

interface Strand {
  jitter: number;
  reach: number;
  inset: number;
  bend: number;
  rate: number;
  phase: number;
}

interface Speck {
  share: number;
  depth: number;
  flicker: number;
}

interface Ray {
  share: number;
  rate: number;
  phase: number;
}

/** Per-strand randomness, computed once: frames only advance time, never re-roll shapes. */
const STRANDS: Strand[] = Array.from({ length: 300 }, (_, index) => {
  const seed = noise(index);
  return {
    jitter: (seed - 0.5) * 0.02,
    reach: 0.4 + 0.45 * seed,
    inset: 0.04 * noise(seed * 91),
    bend: (noise(seed * 17) - 0.5) * 0.12,
    rate: 0.6 + seed * 0.9,
    phase: seed * 40,
  };
});

const SPECKS: Speck[] = Array.from({ length: 900 }, (_, index) => {
  const seed = noise(index * 3.7);
  const depth = noise(seed * 29);
  return { share: noise(index * 1.3), depth: 0.15 + 0.7 * depth * depth, flicker: seed * 13 };
});

const RAYS: Ray[] = Array.from({ length: 48 }, (_, index) => {
  const seed = noise(index * 7.3);
  return { share: (index + noise(index * 5.1)) / 48, rate: 0.5 + seed, phase: seed * 30 };
});

/**
 * Dial drawn like an iris: a woven band of dots round a dark pupil, radial strands with soft
 * prism-coloured rays, grain, and rings of dots at the edge. The remaining share is lit — white,
 * the tool's colour and the prism tints — the rest stays dim. The pupil's rim doubles as a clock:
 * it brightens from 12 o'clock as the window runs, with a dot at the current moment.
 */
export class IrisDial {
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

  /** `elapsedFraction` is 0...1, how much of the window has passed; null hides the rim clock. */
  update(remainingPercent: number, elapsedFraction: number | null, color: Rgb): void {
    this.remainingShare = Math.min(100, Math.max(0, remainingPercent)) / 100;
    this.elapsed = elapsedFraction === null ? null : Math.min(1, Math.max(0, elapsedFraction));
    this.color = color;
  }

  draw(seconds: number): void {
    const time = seconds % TIME_WRAP_SECONDS;
    const center = { x: this.size / 2, y: this.size / 2 };
    const outer = this.size / 2;
    const pupil = outer * PUPIL_RATIO;
    this.context.clearRect(0, 0, this.size, this.size);
    this.drawBackdrop(center, outer);
    this.drawGrain(center, pupil, outer, time);
    this.drawRays(center, outer, time);
    this.drawStrands(center, pupil, outer, time);
    this.drawMesh(center, pupil, outer, time);
    this.drawEdgeRings(center, outer);
    this.drawRimClock(center, pupil * 0.96);
  }

  private drawBackdrop(center: Point, outer: number): void {
    const gradient = this.context.createRadialGradient(center.x, center.y, 0, center.x, center.y, outer);
    gradient.addColorStop(0, rgba(BLACK, 0.6));
    gradient.addColorStop(PUPIL_RATIO * 0.95, rgba(BLACK, 0.5));
    gradient.addColorStop(1, rgba(BLACK, 0));
    this.context.fillStyle = gradient;
    this.context.beginPath();
    this.context.arc(center.x, center.y, outer, 0, FULL_TURN);
    this.context.fill();
  }

  /** Strands are grouped into a few paths by shade, so a frame is a handful of crisp strokes. */
  private drawStrands(center: Point, pupil: number, outer: number, time: number): void {
    const dim = new Path2D();
    const bright = new Path2D();
    const tinted = new Path2D();
    const soft = new Path2D();
    const count = Math.min(STRANDS.length, Math.floor(outer * FIBRES_PER_POINT));
    const span = outer * 0.9 - pupil;
    for (let index = 0; index < count; index++) {
      const strand = STRANDS[index];
      const share = index / count;
      const angle = share * FULL_TURN + TWELVE_OCLOCK + strand.jitter;
      const breath = 0.5 + 0.5 * Math.sin(time * strand.rate + strand.phase);
      const start = pupil * (1.06 + strand.inset);
      const from = pointAt(center, start, angle);
      // A slight sideways drift makes strands read as fibres, not spokes.
      const to = pointAt(center, start + span * (strand.reach + 0.15 * breath), angle + strand.bend);
      const target = share >= this.remainingShare ? dim : [bright, tinted, soft, tinted][index % 4];
      target.moveTo(from.x, from.y);
      target.lineTo(to.x, to.y);
    }
    this.stroke(dim, rgba(WHITE, 0.14), 0.8);
    this.stroke(soft, rgba(WHITE, 0.5), 0.9);
    this.stroke(tinted, rgba(this.color, 0.95), 1.1);
    this.stroke(bright, rgba(WHITE, 0.95), 1.0);
  }

  /** Soft rays across the lit share, alternating the tool's colour with faint prism tints. */
  private drawRays(center: Point, outer: number, time: number): void {
    const paths = Array.from({ length: PRISM.length * 2 }, () => new Path2D());
    RAYS.forEach((ray, index) => {
      if (ray.share >= this.remainingShare) return;
      const swell = 0.5 + 0.5 * Math.sin(time * ray.rate + ray.phase);
      const angle = ray.share * FULL_TURN + TWELVE_OCLOCK;
      const from = pointAt(center, outer * (0.7 - 0.04 * swell), angle);
      const to = pointAt(center, outer * (0.82 + 0.06 * swell), angle);
      const path = paths[index % paths.length];
      path.moveTo(from.x, from.y);
      path.lineTo(to.x, to.y);
    });
    this.context.lineCap = "round";
    paths.forEach((path, index) => {
      const tint = index % 2 === 0 ? rgba(this.color, 0.36) : rgba(PRISM[Math.floor(index / 2)], 0.2);
      this.stroke(path, tint, 2.4);
    });
    this.context.lineCap = "butt";
  }

  /** Rings of dots hugging the pupil, rippling slightly so they read as a woven band. */
  private drawMesh(center: Point, pupil: number, outer: number, time: number): void {
    const lit = new Path2D();
    const dark = new Path2D();
    const dots = Math.floor(outer * MESH_DOTS_PER_POINT);
    for (let ring = 0; ring < MESH_RINGS; ring++) {
      const base = pupil * 1.03 + ring * outer * 0.05;
      for (let dot = 0; dot < dots; dot++) {
        const share = (dot + ring * 0.5) / dots;
        const angle = share * FULL_TURN + TWELVE_OCLOCK;
        const ripple = outer * 0.012 * Math.sin(angle * 5 + time * 0.8 + ring * 1.3);
        this.addDot(share < this.remainingShare ? lit : dark, pointAt(center, base + ripple, angle), 0.65);
      }
    }
    this.fill(dark, rgba(WHITE, 0.18));
    this.fill(lit, rgba(WHITE, 0.85));
  }

  /** Two rings of dots at the rim, lit warm white inside and in the tool's colour outside. */
  private drawEdgeRings(center: Point, outer: number): void {
    const dark = new Path2D();
    EDGE_RINGS.forEach((ring, index) => {
      const lit = new Path2D();
      for (let dot = 0; dot < ring.dots; dot++) {
        const share = dot / ring.dots;
        const spot = pointAt(center, outer * ring.radius, share * FULL_TURN + TWELVE_OCLOCK);
        this.addDot(share < this.remainingShare ? lit : dark, spot, 0.75);
      }
      const isOuter = index === EDGE_RINGS.length - 1;
      this.fill(lit, isOuter ? rgba(this.color, 0.92) : rgba(WARM_WHITE, 0.92));
    });
    this.fill(dark, rgba(WHITE, 0.2));
  }

  /** Stippled grain, densest mid-ring, shimmering as each speck fades in and out. */
  private drawGrain(center: Point, pupil: number, outer: number, time: number): void {
    const lit = new Path2D();
    const dark = new Path2D();
    const flicker = Math.floor(time * 6) % 7;
    const count = Math.min(SPECKS.length, Math.floor(outer * GRAIN_PER_POINT));
    for (const speck of SPECKS.slice(0, count)) {
      if (noise(speck.flicker + flicker) <= 0.35) continue;
      const spot = pointAt(center, pupil + (outer - pupil) * speck.depth, speck.share * FULL_TURN + TWELVE_OCLOCK);
      (speck.share < this.remainingShare ? lit : dark).rect(spot.x - 0.55, spot.y - 0.55, 1.1, 1.1);
    }
    this.fill(dark, rgba(WHITE, 0.18));
    this.fill(lit, rgba(WHITE, 0.7));
  }

  /** The pupil's rim as a clock: faint all round, bright from 12 o'clock to now, dot at now. */
  private drawRimClock(center: Point, radius: number): void {
    const context = this.context;
    context.strokeStyle = rgba(WHITE, 0.1);
    context.lineWidth = 0.8;
    context.beginPath();
    context.arc(center.x, center.y, radius, 0, FULL_TURN);
    context.stroke();
    if (this.elapsed === null) return;

    context.strokeStyle = rgba(WHITE, 0.4);
    context.lineWidth = 1;
    context.lineCap = "round";
    context.beginPath();
    context.arc(center.x, center.y, radius, TWELVE_OCLOCK, TWELVE_OCLOCK + FULL_TURN * this.elapsed);
    context.stroke();
    context.lineCap = "butt";

    const dot = pointAt(center, radius, this.elapsed * FULL_TURN + TWELVE_OCLOCK);
    const glow = context.createRadialGradient(dot.x, dot.y, 0, dot.x, dot.y, 4.5);
    glow.addColorStop(0, rgba(this.color, 0.7));
    glow.addColorStop(1, rgba(this.color, 0));
    context.fillStyle = glow;
    context.beginPath();
    context.arc(dot.x, dot.y, 4.5, 0, FULL_TURN);
    context.fill();
    context.fillStyle = rgba(WHITE, 1);
    context.beginPath();
    context.arc(dot.x, dot.y, 1.6, 0, FULL_TURN);
    context.fill();
  }

  private addDot(path: Path2D, spot: Point, radius: number): void {
    path.moveTo(spot.x + radius, spot.y);
    path.arc(spot.x, spot.y, radius, 0, FULL_TURN);
  }

  private stroke(path: Path2D, style: string | CanvasGradient, width: number): void {
    this.context.strokeStyle = style;
    this.context.lineWidth = width;
    this.context.stroke(path);
  }

  private fill(path: Path2D, style: string): void {
    this.context.fillStyle = style;
    this.context.fill(path);
  }
}
