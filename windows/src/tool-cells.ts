import { hoverLine } from "./clock";
import { brand } from "./theme";
import type { ProviderView } from "./types";

/** Selector of the elements that stand for one tool: a grid cell, or the mark of a one-chart form. */
const TOOL_SELECTOR = "[data-tool]";

export interface ToolCellOptions {
  /** The tool the pointer is over, so a rebuilt page keeps showing it. */
  hovered: string | null;
  /** Opens a tool's page; null when there is nowhere to go (a single tool). */
  open: ((id: string) => void) | null;
  onHover: (id: string | null) => void;
}

/**
 * Wires every element a layout marked with `data-tool`: it brightens under the pointer, a grid
 * cell also glows in the tool's colour and reveals its reset and measuring times in place, and a
 * click opens the tool's page. Layouts only mark their elements; they know nothing of this.
 */
export function attachToolCells(root: HTMLElement, providers: ProviderView[], options: ToolCellOptions): void {
  for (const node of root.querySelectorAll<HTMLElement>(TOOL_SELECTOR)) {
    const provider = providers.find((candidate) => candidate.id === node.dataset.tool);
    if (!provider) continue;
    node.classList.add("tool-cell");
    node.style.setProperty("--tool-tint", brand(provider.id).join(" "));
    if (node.classList.contains("cell")) node.append(reveal(provider));
    node.classList.toggle("clickable", options.open !== null);
    node.classList.toggle("hovered", options.hovered === provider.id);
    node.addEventListener("pointerenter", () => {
      node.classList.add("hovered");
      options.onHover(provider.id);
    });
    node.addEventListener("pointerleave", () => {
      node.classList.remove("hovered");
      options.onHover(null);
    });
    if (options.open) {
      const open = options.open;
      node.addEventListener("click", () => open(provider.id));
    }
  }
}

function reveal(provider: ProviderView): HTMLElement {
  const line = document.createElement("span");
  line.className = "reveal";
  line.textContent = hoverLine(provider);
  return line;
}
