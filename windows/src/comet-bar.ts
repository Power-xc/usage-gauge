import { prepareCanvas } from "./canvas";
import { WHITE, rgba, type Rgb } from "./theme";

const PULSE_CYCLE_SECONDS = 2.8;
const TRACK_ALPHA = 0.1;

/**
 * Remaining share drawn as a streak of light: a fading tail, a white-hot head with a soft flare,
 * and a pulse that runs along the tail towards the head. The bar is `thickness` tall and centred
 * in a taller canvas so the head's flare has room.
 */
export class CometBar {
  readonly canvas = document.createElement("canvas");
  private readonly context: CanvasRenderingContext2D;
  private readonly width: number;
  private readonly height: number;
  private readonly thickness: number;
  private remainingShare = 0;
  private color: Rgb = WHITE;

  constructor(width: number, thickness: number) {
    this.width = width;
    this.thickness = thickness;
    this.height = thickness * 3;
    this.context = prepareCanvas(this.canvas, width, this.height);
    // The extra height is only room for the flare; it must not push the layout apart.
    this.canvas.style.margin = `${-thickness}px 0`;
  }

  update(remainingPercent: number, color: Rgb): void {
    this.remainingShare = Math.min(100, Math.max(0, remainingPercent)) / 100;
    this.color = color;
  }

  draw(seconds: number): void {
    const { context, width, height, thickness } = this;
    const phase = (seconds / PULSE_CYCLE_SECONDS) % 1;
    const top = (height - thickness) / 2;
    context.clearRect(0, 0, width, height);
    context.fillStyle = rgba(WHITE, TRACK_ALPHA);
    context.beginPath();
    context.roundRect(0, top, width, thickness, thickness / 2);
    context.fill();
    if (this.remainingShare <= 0) return;

    const length = Math.max(thickness * 2, width * this.remainingShare);
    const bar = new Path2D();
    bar.roundRect(0, top, length, thickness, thickness / 2);
    const tail = context.createLinearGradient(0, 0, length, 0);
    tail.addColorStop(0, rgba(this.color, 0.08));
    tail.addColorStop(0.55, rgba(this.color, 0.55));
    tail.addColorStop(0.88, rgba(this.color, 1));
    tail.addColorStop(1, rgba(WHITE, 1));
    context.fillStyle = tail;
    context.fill(bar);

    this.drawPulse(bar, length, top, phase);
    this.drawFlare(length);
  }

  /** Pulse travelling along the tail, fading out as it reaches the head. */
  private drawPulse(bar: Path2D, length: number, top: number, phase: number): void {
    const { context, thickness } = this;
    const x = length * phase;
    const reach = thickness * 6;
    const pulse = context.createLinearGradient(x - reach, 0, x + reach, 0);
    pulse.addColorStop(0, rgba(WHITE, 0));
    pulse.addColorStop(0.5, rgba(WHITE, 0.7));
    pulse.addColorStop(1, rgba(WHITE, 0));
    context.save();
    context.clip(bar);
    context.globalAlpha = Math.sin(phase * Math.PI);
    context.fillStyle = pulse;
    context.fillRect(x - reach, top, reach * 2, thickness);
    context.restore();
  }

  private drawFlare(length: number): void {
    const { context, thickness } = this;
    const headX = length - thickness / 2;
    const headY = this.height / 2;
    const flare = thickness * 1.4;
    const glow = context.createRadialGradient(headX, headY, 0, headX, headY, flare * 1.6);
    glow.addColorStop(0, rgba(WHITE, 0.75));
    glow.addColorStop(0.5, rgba(this.color, 0.35));
    glow.addColorStop(1, rgba(this.color, 0));
    context.fillStyle = glow;
    context.beginPath();
    context.ellipse(headX, headY, flare * 1.6, flare, 0, 0, 2 * Math.PI);
    context.fill();
  }
}
