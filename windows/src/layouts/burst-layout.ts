import { burstRays, BURST_SIZE } from "../burst-rays";
import { countdownUntil } from "../countdown";
import { el } from "../dom";
import { WARNING, alert, brand, rgba } from "../theme";
import type { HistoryView, PanelStyle, ProviderView, WindowView } from "../types";
import { buildGrid, toolColumns } from "./grid";
import { nameRow, percentFigure } from "./history-parts";
import { countdown } from "./parts";
import type { LayoutContent } from "./types";

const TOOLS_PER_ROW = 2;
const FIGURE_SIZE = 20;

/** Per tool a starburst of the short window's use, with the remaining share in its middle and the name, burn rate and run-out beside it. Two tools per row. */
export function buildBurstLayout(providers: ProviderView[], style: PanelStyle): LayoutContent {
  return buildGrid(providers, style, toolColumns(providers.length, TOOLS_PER_ROW), (provider, index, width) => buildBlock(provider, index, width, style));
}

function buildBlock(provider: ProviderView, index: number, width: number, style: PanelStyle): HTMLElement {
  const tint = brand(provider.id);
  const window = provider.message === null ? provider.session : null;
  const history = window ? provider.history : null;
  const values = history && !history.isRecording ? history.burstSlices : [];

  const centre = el("div", "burst-centre", percentFigure(window, FIGURE_SIZE, style), el("span", "burst-label", window?.label ?? ""));
  const mark = el("div", "burst-mark", burstRays(values, tint, style), centre);
  mark.style.width = mark.style.height = `${BURST_SIZE}px`;
  const text = el("div", "burst-text", nameRow(provider, index, style, tint), details(provider, window, history, style));
  const block = el("div", "burst-block", mark, text);
  block.style.width = `${width}px`;
  block.classList.toggle("unavailable", provider.message !== null);
  return block;
}

/** "시간당 12%" over "소진 2h 10m" in the alert colour, or "여유" when it lasts to the reset. */
function details(provider: ProviderView, window: WindowView | null, history: HistoryView | null, style: PanelStyle): HTMLElement {
  if (!window || !history) return el("span", "status-text", provider.message === null ? "단기 창 없음" : "연결 안 됨");
  const lines = el("div", "burst-details");
  const burn = history.burnRate;
  if (burn !== null) lines.append(el("span", "muted", `시간당 ${Math.max(1, Math.round(burn))}%`));
  if (history.projectedEmpty !== null) {
    const empty = el("span", "", `소진 ${countdownUntil(history.projectedEmpty, history.now, style)}`);
    empty.style.color = rgba(alert(window.level) ?? WARNING, 1);
    lines.append(empty);
  } else {
    lines.append(el("span", "muted", burn === null ? "사용 없음 · 여유" : "여유"));
  }
  lines.append(el("span", "faint", `초기화 ${countdown(window, style)}`));
  return lines;
}
