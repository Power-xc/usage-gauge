import { countdownUntil } from "../countdown";
import { el } from "../dom";
import { WARNING, alert, brand, rgba } from "../theme";
import { trendChart, TREND_AXIS_INSET } from "../trend-chart";
import { trendSeries, type TrendSeries } from "../trend-series";
import type { PanelStyle, ProviderView, WindowView } from "../types";
import { buildGrid, toolColumns } from "./grid";
import { FIGURE_SIZE, percentFigure } from "./history-parts";
import { NO_READING, providerName } from "./parts";
import type { LayoutContent } from "./types";

const TOOLS_PER_ROW = 2;
/** Data this long makes a burn rate meaningful; below it the caption says it is still recording. */
const ENOUGH_DATA_MS = 10 * 60_000;

/** A line chart of each tool's short window over its whole period, with the remaining share in large type above it and the burn rate in a caption. Two tools per row. */
export function buildTrendLayout(providers: ProviderView[], style: PanelStyle): LayoutContent {
  return buildGrid(providers, style, toolColumns(providers.length, TOOLS_PER_ROW), (provider, index, width) => buildBlock(provider, index, width, style));
}

function buildBlock(provider: ProviderView, index: number, width: number, style: PanelStyle): HTMLElement {
  const tint = brand(provider.id);
  const block = el("div", "history-block", providerName(provider, index, style, tint, true));
  const window = provider.session ?? provider.weekly;
  const history = provider.history;
  if (!window || !history) {
    const figure = el("div", "figure-band", el("span", "status-text", "연결 안 됨"));
    block.append(figure, el("div", "status-detail", provider.message ?? ""));
    const chart = trendChart(null, tint, style, width);
    chart.style.opacity = "0.5";
    block.append(chart, axis(null, style));
    return block;
  }
  const series = trendSeries(history, window);
  block.append(
    el("div", "figure-band", percentFigure(window, FIGURE_SIZE, style)),
    caption(series, window, history.now, style),
    trendChart(series, tint, style, width),
    axis(window, style),
  );
  return block;
}

function caption(series: TrendSeries | null, window: WindowView, now: number, style: PanelStyle): HTMLElement {
  const line = el("div", "caption-line");
  if (series?.burnRate != null) {
    const perHour = `시간당 ${Math.max(1, Math.round(series.burnRate))}%`;
    if (series.projectedEmpty !== null) {
      line.textContent = `${perHour} · ${countdownUntil(series.projectedEmpty, now, style)} 후 소진`;
      line.style.color = rgba(alert(window.level) ?? WARNING, 1);
    } else {
      line.textContent = `${perHour} · 초기화까지 여유`;
    }
  } else if (series && series.recordedSpan >= ENOUGH_DATA_MS) {
    line.textContent = "최근 사용 없음 · 초기화까지 여유";
  } else {
    line.textContent = "기록 중 · 2분마다 쌓여요";
  }
  return line;
}

/** "시작" at the window's start and the time to its reset at the right edge. */
function axis(window: WindowView | null, style: PanelStyle): HTMLElement {
  const hasReset = window !== null && window.countdown !== NO_READING;
  const line = el("div", "axis-line", el("span", "", "시작"), el("span", "", hasReset ? `초기화 ${style === "iris" ? window.countdown : window.countdownCompact}` : ""));
  line.style.paddingLeft = `${TREND_AXIS_INSET}px`;
  line.style.visibility = window ? "visible" : "hidden";
  return line;
}
