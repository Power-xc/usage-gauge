import type { PanelStyle } from "./types";

const MINUTE_MS = 60_000;
const MINUTES_PER_HOUR = 60;
const MINUTES_PER_DAY = 24 * MINUTES_PER_HOUR;
const UNKNOWN = "–";

/** Time from `now` to `until` (epoch ms) in the style's voice: words for iris ("3시간 50분"), terse units for dot and mono ("3h 50m"). */
export function countdownUntil(until: number | null, now: number, style: PanelStyle): string {
  if (until === null) return UNKNOWN;
  const minutes = Math.floor((until - now) / MINUTE_MS);
  const days = Math.floor(minutes / MINUTES_PER_DAY);
  const hours = Math.floor((minutes % MINUTES_PER_DAY) / MINUTES_PER_HOUR);
  const isTerse = style !== "iris";
  if (minutes < 1) return isTerse ? "<1m" : "곧";
  if (minutes >= MINUTES_PER_DAY) return isTerse ? `${days}d ${hours}h` : `${days}일 ${hours}시간`;
  if (minutes >= MINUTES_PER_HOUR) {
    const rest = minutes % MINUTES_PER_HOUR;
    return isTerse ? `${Math.floor(minutes / MINUTES_PER_HOUR)}h ${rest}m` : `${Math.floor(minutes / MINUTES_PER_HOUR)}시간 ${rest}분`;
  }
  return isTerse ? `${minutes}m` : `${minutes}분`;
}
