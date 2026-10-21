import { brand } from "./theme";
import type { ProviderView } from "./types";

/** Selector of the elements that stand for one tool: a grid cell, or the mark of a one-chart form. */
const TOOL_SELECTOR = "[data-tool]";
/** Elements that only follow a tool's focus (the orbit's middle figure, a line of times) and take no pointer. */
const FOLLOWER_SELECTOR = "[data-follows]";

/**
 * A mark that cannot take the pointer itself (a canvas layer under a hit-testing overlay) is told
 * about it with these events, which it handles like the pointer's own.
 */
export const TOOL_ENTER = "toolenter";
export const TOOL_LEAVE = "toolleave";
export const TOOL_OPEN = "toolopen";

export interface ToolCellOptions {
  /** The tool the pointer is over, so a rebuilt page keeps showing it. */
  hovered: string | null;
  /** Opens a tool's page; null when there is nowhere to go (a single tool). */
  open: ((id: string) => void) | null;
  onHover: (id: string | null) => void;
}

/**
 * Wires every element a layout marked with `data-tool`. A grid cell brightens under the pointer,
 * is tinted flat in the tool's colour and swaps a caption for the reset and measuring times (see
 * `revealingCaption`). A mark of a one-chart form (orbit, constellation) focuses its tool: the
 * tool's marks brighten, the other tools' dim a little, and elements that `data-follows` the tool
 * appear. A click opens the tool's page. Layouts only mark their elements; they know nothing of this.
 */
export function attachToolCells(root: HTMLElement, providers: ProviderView[], options: ToolCellOptions): void {
  const known = (node: HTMLElement): ProviderView | undefined => providers.find((candidate) => candidate.id === node.dataset.tool);
  const marks: HTMLElement[] = [];
  root.classList.toggle("opens-tools", options.open !== null);
  for (const node of root.querySelectorAll<HTMLElement>(TOOL_SELECTOR)) {
    const provider = known(node);
    if (!provider) continue;
    const isCell = node.classList.contains("cell");
    node.classList.add("tool-cell");
    node.style.setProperty("--tool-tint", brand(provider.id).join(" "));
    node.classList.toggle("clickable", options.open !== null);
    const enter = (): void => {
      if (isCell) node.classList.add("hovered");
      else focus(provider.id);
      options.onHover(provider.id);
    };
    const leave = (): void => {
      if (isCell) node.classList.remove("hovered");
      else focus(null);
      options.onHover(null);
    };
    node.addEventListener("pointerenter", enter);
    node.addEventListener("pointerleave", leave);
    node.addEventListener(TOOL_ENTER, enter);
    node.addEventListener(TOOL_LEAVE, leave);
    if (options.open) {
      const open = options.open;
      node.addEventListener("click", () => open(provider.id));
      node.addEventListener(TOOL_OPEN, () => open(provider.id));
    }
    if (isCell) node.classList.toggle("hovered", options.hovered === provider.id);
    else marks.push(node);
  }

  function focus(id: string | null): void {
    root.classList.toggle("focusing", id !== null);
    for (const mark of marks) {
      mark.classList.toggle("hovered", mark.dataset.tool === id);
      mark.classList.toggle("dimmed", id !== null && mark.dataset.tool !== id);
    }
    for (const follower of root.querySelectorAll<HTMLElement>(FOLLOWER_SELECTOR)) {
      follower.classList.toggle("hovered", follower.dataset.follows === id);
    }
  }
  if (marks.length > 0) focus(options.hovered);
}
