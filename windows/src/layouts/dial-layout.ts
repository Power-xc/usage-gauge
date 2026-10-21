import type { Drawable } from "../animation";
import { el } from "../dom";
import { brand } from "../theme";
import type { PanelStyle, ProviderView } from "../types";
import { buildGrid } from "./grid";
import { countdown, longWindow, planTag, providerName, sessionGauge } from "./parts";
import type { LayoutContent } from "./types";

const CARDS_PER_ROW = 2;

/** Cards in rows of two: a dial for the short window beside its reset time and a bar for the long one. */
export function buildDialLayout(providers: ProviderView[], style: PanelStyle): LayoutContent {
  return buildGrid(providers, style, CARDS_PER_ROW, (provider, index, _width, drawables) => buildCard(provider, index, style, drawables));
}

function buildCard(provider: ProviderView, index: number, style: PanelStyle, drawables: Drawable[]): HTMLElement {
  const tint = brand(provider.id);
  const isConnected = provider.message === null;
  const title = providerName(provider, index, style, tint);
  title.append(...planTag(provider));
  const detail = el("div", "detail", title);
  if (isConnected) {
    detail.append(el("div", "session-line", sessionLine(provider, style)), longWindow(provider, style, tint, drawables));
  } else {
    detail.append(el("div", "offline", "연결 안 됨"), el("div", "offline-reason", provider.message ?? ""));
  }
  return el("div", "card", sessionGauge(isConnected ? provider.session : null, style, tint, drawables), detail);
}

/** "5시간 · 3시간 50분 후 초기화" ("3h 50m" in the monospaced styles): which window the dial shows and when it resets. */
function sessionLine(provider: ProviderView, style: PanelStyle): string {
  const window = provider.session;
  return `${window?.label ?? "단기"} · ${countdown(window, style)} 후 초기화`;
}
