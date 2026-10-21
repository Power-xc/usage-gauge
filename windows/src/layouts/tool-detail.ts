import type { Drawable } from "../animation";
import { clockTime, measuredText } from "../clock";
import { el } from "../dom";
import { CONTENT_WIDTH, PAGE_DIAL_SIZE, alert, brand, rgba, type Rgb } from "../theme";
import type { PanelStyle, ProviderView, WindowView } from "../types";
import { countdown, percentText, planTag, providerName, sessionGauge, windowBar } from "./parts";
import type { LayoutContent } from "./types";

const COLUMN_GAP = 18;

/**
 * One tool in full: a large dial beside its plan and both windows, each with its remaining share,
 * a bar, the reset as a clock time and a countdown, and when the numbers were measured.
 * `extras` go under the windows, for further sections such as a history chart.
 */
export function buildToolDetail(provider: ProviderView, index: number, style: PanelStyle, extras: HTMLElement[] = []): LayoutContent {
  const drawables: Drawable[] = [];
  const tint = brand(provider.id);
  const isConnected = provider.message === null;
  const dial = sessionGauge(isConnected ? provider.session : null, style, tint, drawables, PAGE_DIAL_SIZE, true);
  const measured = measuredText(provider);
  const head = el(
    "div",
    "tool-head",
    providerName(provider, index, style, tint),
    ...planTag(provider),
    el("span", "spacer"),
    ...(measured ? [el("span", "tool-measured", measured)] : []),
  );
  const side = el("div", "tool-side", head);
  if (isConnected) {
    const barWidth = CONTENT_WIDTH - PAGE_DIAL_SIZE - COLUMN_GAP;
    side.append(
      detailWindow(provider.session, "단기", barWidth, style, tint, drawables),
      detailWindow(provider.weekly, "장기", barWidth, style, tint, drawables),
    );
  } else {
    side.append(el("div", "tool-offline", el("span", "tool-offline-title", "연결 안 됨"), el("span", "tool-offline-reason", provider.message || "로그인을 확인하세요")));
  }
  const page = el("div", "tool-detail", el("div", "tool-main", dial, side), ...extras);
  return { element: el("div", "detail-page", page), drawables };
}

/** Label and remaining share over a bar, then "오후 4:00 초기화 · 3시간 50분 후". */
function detailWindow(
  window: WindowView | null,
  fallbackLabel: string,
  barWidth: number,
  style: PanelStyle,
  tint: Rgb,
  drawables: Drawable[],
): HTMLElement {
  const share = el("span", "tool-share", percentText(window));
  const warning = window ? alert(window.level) : null;
  if (warning) share.style.color = rgba(warning, 1);
  const head = el("div", "tool-window-head", el("span", "tool-label", window?.label ?? fallbackLabel), share);
  const bar = windowBar(style, barWidth, window?.remainingPercent ?? 0, tint, drawables);
  return el("div", "tool-window", head, bar, el("span", "tool-reset", resetLine(window, style)));
}

function resetLine(window: WindowView | null, style: PanelStyle): string {
  if (window?.resetsAt == null) return "초기화 시각 모름";
  return `${clockTime(window.resetsAt)} 초기화 · ${countdown(window, style)} 후`;
}
