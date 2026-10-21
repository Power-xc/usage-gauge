import type { ProviderView } from "./types";

const LOCALE = "ko-KR";
const HOUR_FORMAT: Intl.DateTimeFormatOptions = { hour: "numeric", minute: "2-digit", hour12: true };

/** "오후 4:00" */
export const clockTime = (epochMs: number): string => new Date(epochMs).toLocaleTimeString(LOCALE, HOUR_FORMAT);

/** "4:00": the same without the morning or afternoon word. */
function plainClock(epochMs: number): string {
  return new Intl.DateTimeFormat(LOCALE, HOUR_FORMAT)
    .formatToParts(new Date(epochMs))
    .filter((part) => part.type !== "dayPeriod" && !(part.type === "literal" && part.value.trim() === ""))
    .map((part) => part.value)
    .join("");
}

/**
 * "초기화 오후 4:00 · 측정 12:04"; whichever part is unknown is left out. The compact form keeps
 * the reset only ("오후 4:00 초기화"), for cells too narrow for both.
 */
export function hoverLine(provider: ProviderView, isCompact = false): string {
  const parts: string[] = [];
  const reset = provider.session?.resetsAt ?? provider.weekly?.resetsAt;
  if (isCompact && reset != null) return `${clockTime(reset)} 초기화`;
  if (reset != null) parts.push(`초기화 ${clockTime(reset)}`);
  if (provider.measuredAt !== null) parts.push(`측정 ${plainClock(provider.measuredAt)}`);
  return parts.length > 0 ? parts.join(" · ") : "연결 안 됨";
}

/** "측정 오후 12:04", or nothing when unknown. */
export const measuredText = (provider: ProviderView): string | null =>
  provider.measuredAt === null ? null : `측정 ${clockTime(provider.measuredAt)}`;
