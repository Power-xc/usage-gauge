import { el } from "./dom";
import { shrinkToFit } from "./fit-text";
import { CONTENT_WIDTH, WHITE, brand, rgba, type Rgb } from "./theme";
import type { PanelStyle, ProviderView } from "./types";

/** Approximate advance of one character at the tab type size, per style family. */
const MONO_ADVANCE = 7;
const PROPORTIONAL_ADVANCE = 6.4;
const TAB_CHROME = 26;
const SHORT_NAME_LENGTH = 4;
const OVERVIEW = "전체";
const MIN_LABEL_SCALE = 0.75;
const UNDERLINE_WIDTH = 18;

type Density = "full" | "short" | "marksOnly";

/**
 * "전체" plus one tab per tool, with a short underline in the selected tool's colour (white for
 * the overview) that slides between them. With many tools the names shorten, then drop, so the
 * row never wraps or collides.
 */
export class Tabs {
  readonly element = el("div", "tabs");
  private readonly underline = el("span", "tab-underline");
  private structure = "";
  private count = 0;

  constructor(private readonly select: (id: string | null) => void) {
    this.element.append(this.underline);
  }

  /** `selection` is the open tool's id; null is the overview. Rebuilds the row only when the tools or style changed. */
  update(providers: ProviderView[], style: PanelStyle, selection: string | null): void {
    const density = densityFor(providers, style);
    const structure = `${style}|${density}|${providers.map((provider) => provider.id).join(",")}`;
    if (structure !== this.structure) this.build(providers, style, density, structure);
    this.moveUnderline(providers, style, selection);
  }

  /** Fits any label that still runs wide; needs the row to be in the page. */
  fit(): void {
    for (const label of this.element.querySelectorAll<HTMLElement>(".tab-label")) shrinkToFit(label, MIN_LABEL_SCALE);
  }

  private build(providers: ProviderView[], style: PanelStyle, density: Density, structure: string): void {
    this.structure = structure;
    this.count = providers.length + 1;
    this.element.dataset.style = style;
    this.element.replaceChildren(this.underline, this.tab(null, OVERVIEW, null));
    providers.forEach((provider, index) => {
      const mark = style === "dot" ? el("span", "tab-index", String(index + 1).padStart(2, "0")) : brandMark(provider.id);
      this.element.append(this.tab(provider.id, density === "marksOnly" ? "" : nameFor(provider, density), mark));
    });
  }

  private tab(id: string | null, title: string, mark: HTMLElement | null): HTMLButtonElement {
    const label = el("span", "tab-label", ...(mark ? [mark] : []), ...(title ? [el("span", "tab-name", title)] : []));
    const tab = el("button", "tab", label);
    tab.type = "button";
    tab.dataset.tab = id ?? "";
    tab.addEventListener("click", () => this.select(id));
    return tab;
  }

  private moveUnderline(providers: ProviderView[], style: PanelStyle, selection: string | null): void {
    const at = selection === null ? 0 : providers.findIndex((provider) => provider.id === selection) + 1;
    const center = ((at + 0.5) * CONTENT_WIDTH) / this.count;
    this.underline.style.transform = `translateX(${center - UNDERLINE_WIDTH / 2}px)`;
    this.underline.style.setProperty("--underline", rgba(selection === null ? WHITE : brand(selection), 1));
    this.underline.dataset.style = style;
    for (const tab of this.element.querySelectorAll<HTMLElement>(".tab")) {
      tab.classList.toggle("selected", tab.dataset.tab === (selection ?? ""));
    }
  }
}

function brandMark(id: string): HTMLElement {
  const mark = el("span", "tab-mark");
  const tint: Rgb = brand(id);
  mark.style.background = rgba(tint, 1);
  return mark;
}

const nameFor = (provider: ProviderView, density: Density): string =>
  density === "short" ? provider.title.slice(0, SHORT_NAME_LENGTH) : provider.title;

function densityFor(providers: ProviderView[], style: PanelStyle): Density {
  const advance = style === "iris" ? PROPORTIONAL_ADVANCE : MONO_ADVANCE;
  const fits = (length: (provider: ProviderView) => number): boolean => {
    const letters = providers.map(length).reduce((sum, value) => sum + value, OVERVIEW.length);
    return letters * advance + (providers.length + 1) * TAB_CHROME <= CONTENT_WIDTH;
  };
  if (fits((provider) => provider.title.length)) return "full";
  return fits((provider) => Math.min(provider.title.length, SHORT_NAME_LENGTH)) ? "short" : "marksOnly";
}
