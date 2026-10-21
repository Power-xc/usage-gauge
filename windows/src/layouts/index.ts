import type { PanelLayout, PanelStyle, ProviderView } from "../types";
import { buildBarsLayout } from "./bars-layout";
import { buildCapsuleLayout } from "./capsule-layout";
import { buildColumnsLayout } from "./columns-layout";
import { buildConstellationLayout } from "./constellation-layout";
import { buildDialLayout } from "./dial-layout";
import { buildFiguresLayout } from "./figures-layout";
import { buildOrbitLayout } from "./orbit-layout";
import { buildRulerLayout } from "./ruler-layout";
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
    case "orbit":
      return buildOrbitLayout(providers, style);
    case "capsule":
      return buildCapsuleLayout(providers, style);
    case "constellation":
      return buildConstellationLayout(providers, style);
    case "ruler":
      return buildRulerLayout(providers, style);
  }
}
