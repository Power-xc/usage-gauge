import { easeInOut, frameTime, valueMilliseconds } from "./motion";

/** A number that eases to its new value instead of jumping, so dials and bars glide when a reading changes. */
export class Glide {
  private from = 0;
  private target = 0;
  private startedAt = 0;
  private isPlaced = false;

  /** The first target is taken as is; later ones are glided to from wherever the value is now. */
  to(target: number): void {
    if (!this.isPlaced) {
      this.from = target;
      this.isPlaced = true;
    } else if (target !== this.target) {
      this.from = this.value;
      this.startedAt = frameTime();
    }
    this.target = target;
  }

  /** Starts from what an earlier glide on the same thing was showing, so a rebuilt view still moves from the old value. */
  resume(previous: Glide): void {
    this.from = previous.value;
    this.startedAt = frameTime();
  }

  get value(): number {
    if (this.from === this.target) return this.target;
    const progress = Math.min(1, (frameTime() - this.startedAt) / valueMilliseconds());
    return this.from + (this.target - this.from) * easeInOut(progress);
  }

  get isMoving(): boolean {
    return this.from !== this.target && frameTime() - this.startedAt < valueMilliseconds();
  }
}
