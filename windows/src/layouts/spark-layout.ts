import { el } from "../dom";
import { WHITE, alert, brand, rgba, type Rgb } from "../theme";
import { sparkSlices, sparkStrip } from "../spark-strip";
import type { PanelStyle, ProviderView, WindowView } from "../types";
import { buildGrid } from "./grid";
import { chartSlot } from "./history-parts";
import { countdown, percentText, planTag, providerName, windowBar } from "./parts";
import type { LayoutContent } from "./types";

/** A list, one full-width row per tool: name and short-window share on top, the window's bar, a caption with both resets, and a strip of bars showing what was left over the window so far. */
export function buildSparkLayout(providers: ProviderView[], style: PanelStyle): LayoutContent {
  return buildGrid(providers, style, 1, (provider, index, width, drawables) => {
    const tint = brand(provider.id);
    const block = el("div", "history-block", titleRow(provider, index, style, tint));
    const { session, history } = provider;
    if (session) {
      block.append(windowBar(style, width, session.remainingPercent, tint, drawables), caption(session, provider.weekly, style));
      const isRecording = history?.isRecording ?? true;
      const slices = history?.remainingSlices[style] ?? [];
      const count = isRecording || slices.length === 0 ? sparkSlices(width, style) : slices.length;
      const values = isRecording ? new Array<number | null>(count).fill(null) : slices;
      const nowIndex = session.elapsedFraction === null ? null : Math.min(count - 1, Math.floor(session.elapsedFraction * count));
      block.append(chartSlot(sparkStrip(values, nowIndex, tint, style, width), isRecording));
    }
    block.style.width = `${width}px`;
    block.classList.toggle("unavailable", provider.message !== null);
    return block;
  });
}

function titleRow(provider: ProviderView, index: number, style: PanelStyle, tint: Rgb): HTMLElement {
  const row = el("div", "spark-title", providerName(provider, index, style, tint, true), ...planTag(provider));
  if (provider.message !== null) {
    row.append(el("span", "status-text spark-share", "연결 안 됨"));
    return row;
  }
  const share = el("span", "spark-share", percentText(provider.session));
  share.style.color = rgba((provider.session && alert(provider.session.level)) || WHITE, 1);
  row.append(share);
  return row;
}

/** "5시간 · 3시간 50분 후 초기화" on the left, "주간 37% · 3일 0시간" on the right. */
function caption(window: WindowView, long: WindowView | null, style: PanelStyle): HTMLElement {
  const longLine = long ? [long.label, percentText(long), countdown(long, style)].join(" · ") : "";
  return el("div", "spark-caption", el("span", "", `${window.label || "단기"} · ${countdown(window, style)} 후 초기화`), el("span", "", longLine));
}
