import { el } from "./dom";
import { OPACITY_RANGE } from "./theme";

/**
 * Glass track you grab and drag to set the panel's opacity. The pointer is captured, so the drag
 * stays with the bar and never reaches the window-drag areas.
 */
export class OpacityControl {
  readonly element: HTMLElement;
  private readonly track = el("div", "opacity-track");
  private readonly fill = el("div", "opacity-fill");
  private readonly knob = el("div", "opacity-knob");
  private readonly readout = el("span", "opacity-readout");
  private value: number;

  constructor(value: number, private readonly onChange: (value: number) => void) {
    this.value = value;
    const bar = el("div", "opacity-bar", this.track, this.fill, this.knob);
    this.element = el("div", "opacity-control", el("span", "opacity-label", "투명도"), bar, this.readout);
    bar.addEventListener("pointerdown", (event) => {
      bar.setPointerCapture(event.pointerId);
      this.pick(event, bar);
    });
    bar.addEventListener("pointermove", (event) => {
      if (bar.hasPointerCapture(event.pointerId)) this.pick(event, bar);
    });
    this.show();
  }

  setValue(value: number): void {
    this.value = value;
    this.show();
  }

  private pick(event: PointerEvent, bar: HTMLElement): void {
    const knobSize = this.knob.offsetWidth;
    const travel = Math.max(1, bar.clientWidth - knobSize);
    const rect = bar.getBoundingClientRect();
    const picked = Math.min(1, Math.max(0, (event.clientX - rect.left - knobSize / 2) / travel));
    this.value = OPACITY_RANGE.min + (OPACITY_RANGE.max - OPACITY_RANGE.min) * picked;
    this.show();
    this.onChange(this.value);
  }

  private show(): void {
    const fraction = (this.value - OPACITY_RANGE.min) / (OPACITY_RANGE.max - OPACITY_RANGE.min);
    this.element.style.setProperty("--fraction", String(fraction));
    this.readout.textContent = `${Math.round(this.value * 100)}%`;
  }
}
