import type { Glide } from "./glide";
import { beginFrame } from "./motion";

const FRAME_INTERVAL_MS = 1000 / 12;

export interface Drawable {
  draw(seconds: number): void;
  /** Values that ease towards new readings; a rebuilt view resumes them from the old view's. */
  readonly glides?: readonly Glide[];
}

/** Redraws the drawables at 12 fps, every frame while a value glides; stays idle while paused so a hidden panel costs nothing. */
export class Animation {
  private drawables: Drawable[] = [];
  private key = "";
  private isRunning = false;
  private lastFrame = 0;

  /**
   * Replaces what is animated and paints it once, so new content never waits for a frame. Under
   * the same `key` (same layout, style and tools) the new drawables glide on from the old ones'
   * values, which is how a fresh reading eases in.
   */
  set(drawables: Drawable[], key: string): void {
    beginFrame();
    if (key === this.key) resume(drawables, this.drawables);
    this.key = key;
    this.drawables = drawables;
    this.paint(performance.now());
  }

  setRunning(isRunning: boolean): void {
    if (isRunning === this.isRunning) return;
    this.isRunning = isRunning;
    if (isRunning) requestAnimationFrame(this.frame);
  }

  private frame = (now: number): void => {
    if (!this.isRunning) return;
    beginFrame();
    if (this.isGliding() || now - this.lastFrame >= FRAME_INTERVAL_MS) {
      this.lastFrame = now;
      this.paint(now);
    }
    requestAnimationFrame(this.frame);
  };

  private isGliding(): boolean {
    return this.drawables.some((drawable) => drawable.glides?.some((glide) => glide.isMoving));
  }

  private paint(now: number): void {
    const seconds = now / 1000;
    for (const drawable of this.drawables) drawable.draw(seconds);
  }
}

function resume(next: Drawable[], previous: Drawable[]): void {
  next.forEach((drawable, index) => {
    const before = previous[index]?.glides;
    const glides = drawable.glides;
    if (!before || !glides || before.length !== glides.length) return;
    glides.forEach((glide, at) => glide.resume(before[at]));
  });
}
