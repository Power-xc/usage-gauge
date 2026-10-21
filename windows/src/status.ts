/** "오후 1:51 기준", or a placeholder before the first reading. */
export function statusText(measuredAt: number | null): string {
  if (measuredAt === null) return "불러오는 중";
  const time = new Date(measuredAt).toLocaleTimeString("ko-KR", { hour: "numeric", minute: "2-digit" });
  return `${time} 기준`;
}
