const FRAME_INTERVAL_MS = 1000 / 12;

export interface Drawable {
  draw(seconds: number): void;
}

/** Redraws the drawables at 12 fps; stays idle while paused so a hidden panel costs nothing. */
export class Animation {
  private drawables: Drawable[] = [];
  private isRunning = false;
  private lastFrame = 0;

  /** Replaces what is animated and paints it once, so new content never waits for a frame. */
  set(drawables: Drawable[]): void {
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
    if (now - this.lastFrame >= FRAME_INTERVAL_MS) {
      this.lastFrame = now;
      this.paint(now);
    }
    requestAnimationFrame(this.frame);
  };

  private paint(now: number): void {
    const seconds = now / 1000;
    for (const drawable of this.drawables) drawable.draw(seconds);
  }
}
