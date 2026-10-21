import { el } from "./dom";

/**
 * Glass track you grab and drag to set a value in a range (the panel's opacity or size). The
 * pointer is captured, so the drag stays with the bar and never reaches the window-drag areas.
 */
export class ValueBar {
  readonly element: HTMLElement;
  private readonly knob = el("div", "value-knob");
  private readonly readout = el("span", "value-readout");
  private value: number;

  constructor(
    title: string,
    private readonly range: { min: number; max: number },
    value: number,
    private readonly onChange: (value: number) => void,
  ) {
    this.value = value;
    const bar = el("div", "value-bar", el("div", "value-track"), el("div", "value-fill"), this.knob);
    this.element = el("div", "value-row", el("span", "value-label", title), bar, this.readout);
    bar.addEventListener("pointerdown", (event) => {
      bar.setPointerCapture(event.pointerId);
      this.pick(event, bar);
    });
    bar.addEventListener("pointermove", (event) => {
      if (bar.hasPointerCapture(event.pointerId)) this.pick(event, bar);
    });
    this.show();
  }

  private pick(event: PointerEvent, bar: HTMLElement): void {
    const rect = bar.getBoundingClientRect();
    // The panel may be shown scaled; measure the pointer in the bar's own unscaled pixels.
    const zoom = rect.width / bar.offsetWidth;
    const knobSize = this.knob.offsetWidth;
    const travel = Math.max(1, bar.offsetWidth - knobSize);
    const picked = Math.min(1, Math.max(0, ((event.clientX - rect.left) / zoom - knobSize / 2) / travel));
    this.value = this.range.min + (this.range.max - this.range.min) * picked;
    this.show();
    this.onChange(this.value);
  }

  private show(): void {
    const fraction = (this.value - this.range.min) / (this.range.max - this.range.min);
    this.element.style.setProperty("--fraction", String(fraction));
    this.readout.textContent = `${Math.round(this.value * 100)}%`;
  }
}
