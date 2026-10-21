import { countdownUntil } from "../countdown";
import { el } from "../dom";
import { HISTOGRAM_HEIGHT, histogramColumns } from "../histogram-columns";
import { WHITE, WARNING, alert, brand, rgba } from "../theme";
import type { HistoryView, PanelStyle, ProviderView, WindowView } from "../types";
import { buildGrid, toolColumns } from "./grid";
import { FIGURE_SIZE, MUTED_ALPHA, chartSlot, nameRow, statusPill, styleFigure } from "./history-parts";
import { NO_READING, percentText } from "./parts";
import type { LayoutContent } from "./types";

const TOOLS_PER_ROW = 2;
const HOUR_MS = 3_600_000;
/** Gap between the stacked parts of a block, as in `history.css`. */
const BLOCK_GAP = 6;

/** Per tool a histogram of the short window's recent use: what was used in the last hour in large type, a column per slice of the window, and whether the allowance lasts until the reset. Two tools per row. */
export function buildHistogramLayout(providers: ProviderView[], style: PanelStyle): LayoutContent {
  return buildGrid(providers, style, toolColumns(providers.length, TOOLS_PER_ROW), (provider, index, width) => buildBlock(provider, index, width, style));
}

function buildBlock(provider: ProviderView, index: number, width: number, style: PanelStyle): HTMLElement {
  const tint = brand(provider.id);
  const block = el("div", "history-block", nameRow(provider, index, style, tint, width));
  const { session, history } = provider;
  if (!session || !history) {
    const status = el("div", "status-text", provider.message === null ? "단기 창 없음" : "연결 안 됨");
    status.style.height = `${FIGURE_SIZE + BLOCK_GAP + HISTOGRAM_HEIGHT}px`;
    block.append(status);
    return block;
  }
  const usedLastHour = history.isRecording ? null : usedInLastHour(history);
  const note = usedLastHour === 0 ? "최근 1시간 사용 없음" : "최근 1시간 사용";
  const figure = styleFigure(usedLastHour === null ? NO_READING : String(Math.round(usedLastHour)), usedLastHour !== null, WHITE, FIGURE_SIZE, style);
  block.append(
    el("div", "figure-band", el("div", "figure-line", figure, el("span", "figure-note", note))),
    chartSlot(histogramColumns(history.isRecording ? [] : history.usedSlices, tint, style, width), history.isRecording),
    footer(session, history, style),
  );
  return block;
}

/** What the window lost over the last hour, summed from the recorded drops. */
function usedInLastHour(history: HistoryView): number {
  const recent = history.points.filter((point) => point.at >= history.now - HOUR_MS);
  return recent.slice(1).reduce((used, point, index) => used + Math.max(0, recent[index].remaining - point.remaining), 0);
}

function footer(window: WindowView, history: HistoryView, style: PanelStyle): HTMLElement {
  const warning = alert(window.level);
  const share = el("span", "footer-share", percentText(window));
  share.style.color = rgba(warning ?? WHITE, 1);
  const status =
    history.projectedEmpty === null
      ? statusPill("여유", rgba(WHITE, MUTED_ALPHA))
      : statusPill(`소진 ${countdownUntil(history.projectedEmpty, history.now, style)}`, rgba(warning ?? WARNING, 1));
  return el("div", "footer-line", el("span", "footer-label", `${window.label || "단기"} · 남은`), share, status);
}
