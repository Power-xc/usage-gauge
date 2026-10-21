import { Animation } from "./animation";
import { bridge } from "./bridge";
import { el } from "./dom";
import { setPanelScale } from "./canvas";
import { makeDraggable } from "./drag";
import { LayoutPicker } from "./layout-picker";
import { buildLayout } from "./layouts";
import { buildToolDetail } from "./layouts/tool-detail";
import type { LayoutContent } from "./layouts/types";
import { enter, leave } from "./motion";
import { PageSlot } from "./page-slot";
import { panelControls } from "./panel-controls";
import { statusText } from "./status";
import { Tabs } from "./tabs";
import { attachToolCells } from "./tool-cells";
import type { PanelLayout, PanelState, PanelStyle, ProviderView, UsageView } from "./types";
import { WindowFit } from "./window-fit";

const PICKER_GLYPH =
  '<svg viewBox="0 0 12 12" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.2" stroke-linejoin="round"><rect x="1.5" y="1.5" width="3.4" height="3.4" rx=".9"/><rect x="7.1" y="1.5" width="3.4" height="3.4" rx=".9"/><rect x="1.5" y="7.1" width="3.4" height="3.4" rx=".9"/><rect x="7.1" y="7.1" width="3.4" height="3.4" rx=".9"/></svg>';
const ADJUST_GLYPH =
  '<svg viewBox="0 0 12 12" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"><path d="M1.5 2.5h9M1.5 6h9M1.5 9.5h9"/><circle cx="4" cy="2.5" r="1.3" fill="#000"/><circle cx="8" cy="6" r="1.3" fill="#000"/><circle cx="5" cy="9.5" r="1.3" fill="#000"/></svg>';
const CLOSE_GLYPH =
  '<svg viewBox="0 0 12 12" width="12" height="12"><path d="M2.5 2.5l7 7m0-7l-7 7" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/></svg>';

/** The section under the header; only one is open at a time. */
type Section = "picker" | "controls";

/** The whole panel: header, optional picker or opacity and size bars, the tabs and the page, arranged by the layout and drawn in the chosen style. */
export class Panel {
  /** Header plus the picker or the opacity and size bars when open; the mono style sets both in one cell of its grid. */
  private readonly head = el("div", "head");
  private readonly header = el("div", "header");
  private readonly status = el("span", "status");
  private readonly pickerToggle = glyphButton(PICKER_GLYPH, "그래프 모양");
  private readonly adjustToggle = glyphButton(ADJUST_GLYPH, "투명도 · 크기");
  private readonly sections: Record<Section, HTMLElement>;
  private readonly picker: LayoutPicker;
  private readonly tabs = new Tabs((id) => this.open(id));
  private readonly page = new PageSlot();
  private readonly animation = new Animation();
  private readonly fitter: WindowFit;
  private readonly panel: HTMLElement;
  private usage: UsageView;
  private style: PanelStyle;
  private layout: PanelLayout;
  private scale: number;
  private openSection: Section | null = null;
  /** The tool whose page is open; null shows the layout. */
  private selected: string | null = null;
  private hovered: string | null = null;
  private isRenderQueued = false;
  private opacity: number;

  constructor(private readonly root: HTMLElement, state: PanelState) {
    this.opacity = state.opacity;
    this.usage = state.usage;
    this.style = state.style;
    this.layout = state.layout;
    this.scale = state.scale;
    this.picker = new LayoutPicker(state.layouts, state.layout, (id) => void bridge.chooseLayout(id));
    this.sections = {
      picker: this.picker.element,
      controls: panelControls(state.opacity, state.scale, (value) => this.setOpacity(value), (value) => this.setScale(value)),
    };
    const close = glyphButton(CLOSE_GLYPH, "숨기기 (Ctrl+Alt+U)");
    close.addEventListener("click", () => void bridge.hidePanel());
    this.pickerToggle.addEventListener("click", () => this.toggle("picker"));
    this.adjustToggle.addEventListener("click", () => this.toggle("controls"));
    this.header.append(
      el("span", "lamp"),
      el("span", "header-title", "남은 사용량"),
      el("span", "spacer"),
      this.status,
      this.pickerToggle,
      this.adjustToggle,
      close,
    );

    this.head.append(this.header);
    this.panel = el("div", state.hasGlass ? "panel" : "panel solid", this.head, this.page.element);
    this.panel.dataset.style = state.style;
    this.panel.dataset.layout = state.layout;
    this.fitter = new WindowFit(this.panel, () => this.scale);
    for (const area of [this.header, this.page.element]) makeDraggable(area);
    this.root.replaceChildren(this.panel);
    this.applyOpacity();
    this.applyScale();
    this.render(state.usage);
    this.setShown(state.isShown);
  }

  render(usage: UsageView): void {
    this.renderPage(usage, false);
  }

  /** Restyles the panel live and resizes the window to the new layout. */
  setStyle(style: PanelStyle): void {
    this.style = style;
    this.panel.dataset.style = style;
    this.renderPage(this.usage, false);
  }

  /** Rearranges the panel live and resizes the window to the new layout. */
  setLayout(layout: PanelLayout): void {
    this.layout = layout;
    this.panel.dataset.layout = layout;
    this.picker.select(layout);
    this.renderPage(this.usage, false);
  }

  /** Animations stop while the panel is hidden. */
  setShown(isShown: boolean): void {
    this.animation.setRunning(isShown);
  }

  private get showsTabs(): boolean {
    return this.usage.providers.length > 1;
  }

  /** The tool whose page is open; one that has disappeared falls back to the overview. */
  private selectedProvider(): ProviderView | null {
    if (!this.showsTabs || this.selected === null) return null;
    return this.usage.providers.find((provider) => provider.id === this.selected) ?? null;
  }

  private open(id: string | null): void {
    this.selected = id;
    this.renderPage(this.usage, false);
  }

  private renderPage(usage: UsageView, isImmediate: boolean): void {
    this.usage = usage;
    this.status.textContent = statusText(usage.measuredAt);
    const selected = this.selectedProvider();
    const content = selected ? this.detail(selected) : buildLayout(this.layout, usage.providers, this.style);
    const key = `${this.layout}|${this.style}|${selected?.id ?? ""}`;
    attachToolCells(content.element, usage.providers, {
      hovered: this.hovered,
      open: this.showsTabs ? (id) => this.open(id) : null,
      onHover: (id) => (this.hovered = id),
    });
    const changed = this.page.show(key, content);
    this.animation.set(content.drawables, `${key}|${usage.providers.map((provider) => provider.id).join(",")}`);
    this.syncTabs(selected);
    this.fitter.fit(changed && !isImmediate);
  }

  private detail(provider: ProviderView): LayoutContent {
    return buildToolDetail(provider, this.usage.providers.indexOf(provider), this.style);
  }

  private syncTabs(selected: ProviderView | null): void {
    if (this.showsTabs) {
      this.tabs.update(this.usage.providers, this.style, selected?.id ?? null);
      if (!this.tabs.element.isConnected) this.head.after(this.tabs.element);
      this.tabs.fit();
    } else {
      this.tabs.element.remove();
    }
  }

  private toggle(section: Section): void {
    const next = this.openSection === section ? null : section;
    if (this.openSection) leave(this.sections[this.openSection], "section");
    this.openSection = next;
    if (next) {
      this.header.after(this.sections[next]);
      enter(this.sections[next], "section");
      if (next === "picker") this.picker.fit();
    }
    this.pickerToggle.classList.toggle("on", next === "picker");
    this.adjustToggle.classList.toggle("on", next === "controls");
    this.fitter.fit(true);
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
      this.renderPage(this.usage, true);
    });
  }

  /** Scaling is a render transform from the top-left corner, so text and canvases are drawn at the final size. */
  private applyScale(): void {
    setPanelScale(this.scale);
    this.root.style.transformOrigin = "0 0";
    this.root.style.transform = `scale(${this.scale})`;
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
