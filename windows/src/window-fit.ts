import { bridge } from "./bridge";
import { easeInOut, pageMilliseconds } from "./motion";

/**
 * Keeps the window the size of the panel. When the content grows or shrinks (a tool page, the
 * picker) the panel's height eases to the new one and the window follows each frame, so nothing
 * snaps; the first fit and size changes from scaling are immediate.
 */
export class WindowFit {
  private shown: number | null = null;
  private tween = 0;

  constructor(
    private readonly panel: HTMLElement,
    private readonly scale: () => number,
  ) {}

  fit(animate: boolean): void {
    cancelAnimationFrame(this.tween);
    this.panel.classList.remove("fitting");
    this.panel.style.height = "";
    const target = this.panel.offsetHeight;
    const from = this.shown;
    if (!animate || from === null || from === target) {
      this.apply(target);
      return;
    }
    this.panel.classList.add("fitting");
    let startedAt: number | null = null;
    const step = (now: number): void => {
      startedAt ??= now;
      const progress = Math.min(1, (now - startedAt) / pageMilliseconds());
      if (progress >= 1) {
        this.panel.classList.remove("fitting");
        this.panel.style.height = "";
        this.apply(target);
        return;
      }
      const height = from + (target - from) * easeInOut(progress);
      this.panel.style.height = `${height}px`;
      this.apply(height);
      this.tween = requestAnimationFrame(step);
    };
    this.tween = requestAnimationFrame(step);
  }

  private apply(height: number): void {
    this.shown = height;
    const scale = this.scale();
    void bridge.resize(Math.ceil(this.panel.offsetWidth * scale), Math.ceil(height * scale));
  }
}
