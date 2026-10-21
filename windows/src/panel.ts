import { Animation } from "./animation";
import { bridge } from "./bridge";
import { el } from "./dom";
import { setPanelScale } from "./canvas";
import { buildLayout } from "./layouts";
import { panelControls } from "./panel-controls";
import { statusText } from "./status";
import type { PanelLayout, PanelState, PanelStyle, UsageView } from "./types";

const ADJUST_GLYPH =
  '<svg viewBox="0 0 12 12" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"><path d="M1.5 2.5h9M1.5 6h9M1.5 9.5h9"/><circle cx="4" cy="2.5" r="1.3" fill="#000"/><circle cx="8" cy="6" r="1.3" fill="#000"/><circle cx="5" cy="9.5" r="1.3" fill="#000"/></svg>';
const CLOSE_GLYPH =
  '<svg viewBox="0 0 12 12" width="12" height="12"><path d="M2.5 2.5l7 7m0-7l-7 7" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/></svg>';

/** The whole panel: header, optional opacity and size bars and the providers, arranged by the layout and drawn in the chosen style. */
export class Panel {
  /** Header plus the opacity and size bars when open; the mono style sets both in one cell of its grid. */
  private readonly head = el("div", "head");
  private readonly header = el("div", "header");
  private readonly status = el("span", "status");
  private readonly adjustToggle = glyphButton(ADJUST_GLYPH, "조절");
  private readonly controls: HTMLElement;
  private readonly gridSlot = el("div", "grid-slot");
  private readonly animation = new Animation();
  private readonly panel: HTMLElement;
  private usage: UsageView;
  private style: PanelStyle;
  private layout: PanelLayout;
  private scale: number;
  private isAdjusting = false;
  private isRenderQueued = false;
  private opacity: number;

  constructor(private readonly root: HTMLElement, state: PanelState) {
    this.opacity = state.opacity;
    this.usage = state.usage;
    this.style = state.style;
    this.layout = state.layout;
    this.scale = state.scale;
    this.controls = panelControls(
      state.opacity,
      state.scale,
      (value) => this.setOpacity(value),
      (value) => this.setScale(value),
    );
    const close = glyphButton(CLOSE_GLYPH, "숨기기 (Ctrl+Alt+U)");
    close.addEventListener("click", () => void bridge.hidePanel());
    this.adjustToggle.addEventListener("click", () => this.toggleControls());
    this.header.append(el("span", "lamp"), el("span", "header-title", "남은 사용량"), el("span", "spacer"), this.status, this.adjustToggle, close);

    this.head.append(this.header);
    this.panel = el("div", state.hasGlass ? "panel" : "panel solid", this.head, this.gridSlot);
    this.panel.dataset.style = state.style;
    this.panel.dataset.layout = state.layout;
    for (const area of [this.header, this.gridSlot]) {
      area.addEventListener("mousedown", (event) => this.startDrag(event));
    }
    this.root.replaceChildren(this.panel);
    this.applyOpacity();
    this.applyScale();
    this.render(state.usage);
    this.setShown(state.isShown);
  }

  render(usage: UsageView): void {
    this.usage = usage;
    this.status.textContent = statusText(usage.measuredAt);
    const content = buildLayout(this.layout, usage.providers, this.style);
    this.gridSlot.replaceChildren(content.element);
    this.animation.set(content.drawables);
    this.fitWindow();
  }

  /** Restyles the panel live and resizes the window to the new layout. */
  setStyle(style: PanelStyle): void {
    this.style = style;
    this.panel.dataset.style = style;
    this.render(this.usage);
  }

  /** Rearranges the panel live and resizes the window to the new layout. */
  setLayout(layout: PanelLayout): void {
    this.layout = layout;
    this.panel.dataset.layout = layout;
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

  private toggleControls(): void {
    this.isAdjusting = !this.isAdjusting;
    this.adjustToggle.classList.toggle("on", this.isAdjusting);
    if (this.isAdjusting) this.header.after(this.controls);
    else this.controls.remove();
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

  /** Sizes the panel while the bar is dragged; canvases are rebuilt once per frame so they stay crisp. */
  private setScale(value: number): void {
    this.scale = value;
    this.applyScale();
    void bridge.setScale(value);
    if (this.isRenderQueued) return;
    this.isRenderQueued = true;
    requestAnimationFrame(() => {
      this.isRenderQueued = false;
      this.render(this.usage);
    });
  }

  /** Scaling is a render transform from the top-left corner, so text and canvases are drawn at the final size. */
  private applyScale(): void {
    setPanelScale(this.scale);
    this.root.style.transformOrigin = "0 0";
    this.root.style.transform = `scale(${this.scale})`;
  }

  /** The window follows the scaled content, e.g. when the bars appear. */
  private fitWindow(): void {
    void bridge.resize(Math.ceil(this.panel.offsetWidth * this.scale), Math.ceil(this.panel.offsetHeight * this.scale));
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
