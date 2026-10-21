import type { PanelLayout, PanelStyle, ProviderView } from "../types";
import { buildBarsLayout } from "./bars-layout";
import { buildColumnsLayout } from "./columns-layout";
import { buildDialLayout } from "./dial-layout";
import { buildFiguresLayout } from "./figures-layout";
import type { LayoutContent } from "./types";

/** One module per layout; a new layout adds its builder and a case here (and its id in the Rust `PanelLayout`). */
export function buildLayout(layout: PanelLayout, providers: ProviderView[], style: PanelStyle): LayoutContent {
  switch (layout) {
    case "dial":
      return buildDialLayout(providers, style);
    case "bars":
      return buildBarsLayout(providers, style);
    case "columns":
      return buildColumnsLayout(providers, style);
    case "figures":
      return buildFiguresLayout(providers, style);
  }
}
