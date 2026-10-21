import { Animation } from "./animation";
import { bridge } from "./bridge";
import { el } from "./dom";
import { buildGrid } from "./gauge-view";
import { OpacityControl } from "./opacity-bar";
import { statusText } from "./status";
import type { PanelState, PanelStyle, UsageView } from "./types";

const OPACITY_GLYPH =
  '<svg viewBox="0 0 12 12" width="12" height="12"><circle cx="6" cy="6" r="4.6" fill="none" stroke="currentColor" stroke-width="1.2"/><path d="M6 1.4a4.6 4.6 0 0 0 0 9.2z" fill="currentColor"/></svg>';
const CLOSE_GLYPH =
  '<svg viewBox="0 0 12 12" width="12" height="12"><path d="M2.5 2.5l7 7m0-7l-7 7" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/></svg>';

/** The whole panel: header, optional opacity bar and the provider grid, drawn in the chosen style. */
export class Panel {
  /** Header plus the opacity bar when open; the mono style sets both in one cell of its grid. */
  private readonly head = el("div", "head");
  private readonly header = el("div", "header");
  private readonly status = el("span", "status");
  private readonly opacityToggle = glyphButton(OPACITY_GLYPH, "투명도");
  private readonly opacityControl: OpacityControl;
  private readonly gridSlot = el("div", "grid-slot");
  private readonly animation = new Animation();
  private readonly panel: HTMLElement;
  private usage: UsageView;
  private style: PanelStyle;
  private isAdjustingOpacity = false;
  private opacity: number;

  constructor(private readonly root: HTMLElement, state: PanelState) {
    this.opacity = state.opacity;
    this.usage = state.usage;
    this.style = state.style;
    this.opacityControl = new OpacityControl(state.opacity, (value) => this.setOpacity(value));
    const close = glyphButton(CLOSE_GLYPH, "숨기기 (Ctrl+Alt+U)");
    close.addEventListener("click", () => void bridge.hidePanel());
    this.opacityToggle.addEventListener("click", () => this.toggleOpacityControl());
    this.header.append(el("span", "lamp"), el("span", "header-title", "남은 사용량"), el("span", "spacer"), this.status, this.opacityToggle, close);

    this.head.append(this.header);
    this.panel = el("div", state.hasGlass ? "panel" : "panel solid", this.head, this.gridSlot);
    this.panel.dataset.style = state.style;
    for (const area of [this.header, this.gridSlot]) {
      area.addEventListener("mousedown", (event) => this.startDrag(event));
    }
    this.root.replaceChildren(this.panel);
    this.applyOpacity();
    this.render(state.usage);
    this.setShown(state.isShown);
  }

  render(usage: UsageView): void {
    this.usage = usage;
    this.status.textContent = statusText(usage.measuredAt);
    const grid = buildGrid(usage.providers, this.style);
    this.gridSlot.replaceChildren(grid.element);
    this.animation.set(grid.drawables);
    this.fitWindow();
  }

  /** Restyles the panel live and resizes the window to the new layout. */
  setStyle(style: PanelStyle): void {
    this.style = style;
    this.panel.dataset.style = style;
    this.render(this.usage);
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
    void bridge.resize(Math.ceil(this.panel.offsetWidth), Math.ceil(this.panel.offsetHeight));
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
