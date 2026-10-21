import type { Drawable } from "../animation";
import { capsuleBar } from "../capsule-bar";
import { el } from "../dom";
import { percentFigure } from "../figure";
import { brand } from "../theme";
import type { PanelStyle, ProviderView } from "../types";
import { revealingCaption } from "../reveal";
import { buildGrid, toolColumns } from "./grid";
import { countdown, longWindow, planTag, providerName } from "./parts";
import type { LayoutContent } from "./types";

const TOOLS_PER_ROW = 2;
const FIGURE_SIZE = 26;

/** Per tool a horizontal capsule filled to the short window's remaining share, with the long window as a thin bar under it. */
export function buildCapsuleLayout(providers: ProviderView[], style: PanelStyle): LayoutContent {
  return buildGrid(providers, style, toolColumns(providers.length, TOOLS_PER_ROW), (provider, index, width, drawables) =>
    buildBlock(provider, index, width, style, drawables),
  );
}

function buildBlock(provider: ProviderView, index: number, width: number, style: PanelStyle, drawables: Drawable[]): HTMLElement {
  const tint = brand(provider.id);
  const isConnected = provider.message === null;
  const title = el("div", "capsule-title", providerName(provider, index, style, tint), ...planTag(provider));
  const head = el("div", "capsule-head", title, readout(provider, width, style));
  const bar = capsuleBar(style, width, isConnected ? (provider.session?.remainingPercent ?? 0) : 0, tint);
  return el("div", "capsule-block", head, bar, longWindow(isConnected ? provider : { ...provider, weekly: null }, style, tint, drawables, width));
}

/** The big share with the reset countdown under it, at the right end. */
function readout(provider: ProviderView, width: number, style: PanelStyle): HTMLElement {
  if (provider.message !== null) {
    const status = el("div", "capsule-status", "연결 안 됨");
    return el("div", "capsule-readout", status, el("span", "caption", provider.message));
  }
  const caption = revealingCaption(provider, el("span", "caption", countdown(provider.session, style)), { align: "trailing", width });
  return el("div", "capsule-readout", percentFigure(provider.session, FIGURE_SIZE, style), caption);
}
