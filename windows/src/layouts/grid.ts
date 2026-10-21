import type { Drawable } from "../animation";
import { el } from "../dom";
import { CELL_SPACING, CONTENT_WIDTH, PANEL_PADDING } from "../theme";
import type { PanelStyle, ProviderView } from "../types";
import type { BlockBuilder, LayoutContent } from "./types";

/**
 * Providers in rows of `columns` equal cells, set apart by space alone; the mono style sets them
 * in a hairline grid that runs edge to edge instead (see `style.css`). Blocks get the width left
 * for their content.
 */
export function buildGrid(providers: ProviderView[], style: PanelStyle, columns: number, block: BlockBuilder): LayoutContent {
  const drawables: Drawable[] = [];
  const width = cellWidth(columns, style);
  const isMono = style === "mono";
  const grid = el("div", "grid");
  for (let start = 0; start < providers.length; start += columns) {
    const row = el("div", "row");
    providers.slice(start, start + columns).forEach((provider, offset) => {
      const cell = el("div", "cell", block(provider, start + offset, width, drawables));
      cell.style.width = `${isMono ? width + 2 * PANEL_PADDING : width}px`;
      row.append(cell);
    });
    grid.append(row);
  }
  return { element: grid, drawables };
}

/** One chart for every tool, `CONTENT_WIDTH` wide; mono sets it between hairlines like a grid row. */
export function singleCell(content: HTMLElement, style: PanelStyle): LayoutContent {
  const isMono = style === "mono";
  const cell = el("div", "cell", content);
  cell.style.width = `${isMono ? CONTENT_WIDTH + 2 * PANEL_PADDING : CONTENT_WIDTH}px`;
  return { element: el("div", "grid", el("div", "row", cell)), drawables: [] };
}

/** Columns for a row of tools that wraps after `perRow`. */
export const toolColumns = (count: number, perRow: number): number => Math.min(perRow, Math.max(count, 1));

/** Mono cells also cover the panel padding and pay for the one-pixel rules between them. */
function cellWidth(columns: number, style: PanelStyle): number {
  if (style === "mono") {
    const total = CONTENT_WIDTH + 2 * PANEL_PADDING + 1;
    return Math.floor((total - (columns - 1)) / columns - 2 * PANEL_PADDING);
  }
  return Math.floor((CONTENT_WIDTH - (columns - 1) * CELL_SPACING) / columns);
}
