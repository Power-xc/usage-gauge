import { Animation } from "./animation";
import { bridge } from "./bridge";
import { el } from "./dom";
import { buildGrid } from "./gauge-view";
import { OpacityControl } from "./opacity-bar";
import { statusText } from "./status";
import type { PanelState, UsageView } from "./types";

const OPACITY_GLYPH =
  '<svg viewBox="0 0 12 12" width="12" height="12"><circle cx="6" cy="6" r="4.6" fill="none" stroke="currentColor" stroke-width="1.2"/><path d="M6 1.4a4.6 4.6 0 0 0 0 9.2z" fill="currentColor"/></svg>';
const CLOSE_GLYPH =
  '<svg viewBox="0 0 12 12" width="12" height="12"><path d="M2.5 2.5l7 7m0-7l-7 7" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/></svg>';

/** The whole panel: header, optional opacity bar and the provider grid. */
export class Panel {
  private readonly header = el("div", "header");
  private readonly status = el("span", "status");
  private readonly opacityToggle = glyphButton(OPACITY_GLYPH, "투명도");
  private readonly opacityControl: OpacityControl;
  private readonly gridSlot = el("div", "grid-slot");
  private readonly animation = new Animation();
  private isAdjustingOpacity = false;
  private opacity: number;

  constructor(private readonly root: HTMLElement, state: PanelState) {
    this.opacity = state.opacity;
    this.opacityControl = new OpacityControl(state.opacity, (value) => this.setOpacity(value));
    const close = glyphButton(CLOSE_GLYPH, "숨기기 (Ctrl+Alt+U)");
    close.addEventListener("click", () => void bridge.hidePanel());
    this.opacityToggle.addEventListener("click", () => this.toggleOpacityControl());
    this.header.append(el("span", "header-title", "남은 사용량"), el("span", "spacer"), this.status, this.opacityToggle, close);

    const panel = el("div", state.hasGlass ? "panel" : "panel solid", this.header, this.gridSlot);
    for (const area of [this.header, this.gridSlot]) {
      area.addEventListener("mousedown", (event) => this.startDrag(event));
    }
    this.root.replaceChildren(panel);
    this.applyOpacity();
    this.render(state.usage);
    this.setShown(state.isShown);
  }

  render(usage: UsageView): void {
    this.status.textContent = statusText(usage.measuredAt);
    const grid = buildGrid(usage.providers);
    this.gridSlot.replaceChildren(grid.element);
    this.animation.set(grid.drawables);
    this.fitWindow();
  }

  /** Animations stop while the panel is hidden. */
  setShown(isShown: boolean): void {
    this.animation.setRunning(isShown);
  }

  private startDrag(event: MouseEvent): void {
    const target = event.target as HTMLElement;
    if (event.button !== 0 || target.closest("button")) return;
    void bridge.startDragging();
  }

  private toggleOpacityControl(): void {
    this.isAdjustingOpacity = !this.isAdjustingOpacity;
    this.opacityToggle.classList.toggle("on", this.isAdjustingOpacity);
    if (this.isAdjustingOpacity) this.header.after(this.opacityControl.element);
    else this.opacityControl.element.remove();
    this.fitWindow();
  }

  private setOpacity(value: number): void {
    this.opacity = value;
    this.applyOpacity();
    void bridge.setOpacity(value);
  }

  private applyOpacity(): void {
    this.root.style.opacity = String(this.opacity);
  }

  /** The window follows the content, e.g. when the opacity bar appears. */
  private fitWindow(): void {
    const panel = this.root.firstElementChild as HTMLElement;
    void bridge.resize(Math.ceil(panel.offsetWidth), Math.ceil(panel.offsetHeight));
  }
}

function glyphButton(svg: string, help: string): HTMLButtonElement {
  const button = el("button", "glyph");
  button.type = "button";
  button.title = help;
  button.setAttribute("aria-label", help);
  button.innerHTML = svg;
  return button;
}
