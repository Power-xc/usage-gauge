const OPEN = '<svg viewBox="0 0 14 14" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.1" stroke-linecap="round" stroke-linejoin="round">';

const draw = (body: string): string => `${OPEN}${body}</svg>`;

/** One 14 pt line glyph per graph form, by layout id; the grid glyph is for forms without their own. */
export const LAYOUT_GLYPHS: Record<string, string> = {
  dial: draw('<path d="M2.2 10.6a5.6 5.6 0 1 1 9.6 0"/><path d="M7 8.2 9.4 4.8"/><circle cx="7" cy="8.4" r=".7" fill="currentColor"/>'),
  bars: draw('<path d="M2 3.5h10M2 7h6.5M2 10.5h8"/>'),
  columns: draw('<path d="M3.5 12V7M7 12V2.5M10.5 12V5"/>'),
  figures: draw('<path d="M5.2 2 4.2 12M9.8 2 8.8 12M2.4 5h9.6M2 9h9.6"/>'),
  orbit: draw('<circle cx="7" cy="7" r="1.2"/><circle cx="7" cy="7" r="3.2"/><circle cx="7" cy="7" r="5.4"/>'),
  capsule: draw('<rect x="4.2" y="1.8" width="5.6" height="10.4" rx="2.8"/><path d="M4.2 8h5.6"/>'),
  trend: draw('<path d="M1.8 10.5 5 6.4l2.6 2.4 4.6-5.6"/>'),
  histogram: draw('<path d="M2 12V8.5M4.8 12V4M7.6 12V6.5M10.4 12V2.5"/>'),
  spark: draw('<path d="M2 4h10M2 7h10M2 10h10"/><path d="M2 4h5M2 7h8M2 10h3" stroke-width="2"/>'),
  burst: draw('<path d="M7 1.6v3M7 9.4v3M1.6 7h3M9.4 7h3M3.2 3.2l2.1 2.1M8.7 8.7l2.1 2.1M10.8 3.2 8.7 5.3M5.3 8.7l-2.1 2.1"/>'),
  constellation: draw('<path d="m3 10.5 3-5 3.5 2.5 2-4.5"/><circle cx="3" cy="10.5" r="1" fill="currentColor"/><circle cx="6" cy="5.5" r="1" fill="currentColor"/><circle cx="9.5" cy="8" r="1" fill="currentColor"/><circle cx="11.5" cy="3.5" r="1" fill="currentColor"/>'),
  ruler: draw('<path d="M7 1.8v10.4M7 2.8h3M7 5h1.8M7 7h3M7 9h1.8M7 11h3"/>'),
  fallback: draw('<rect x="2" y="2" width="4" height="4" rx="1"/><rect x="8" y="2" width="4" height="4" rx="1"/><rect x="2" y="8" width="4" height="4" rx="1"/><rect x="8" y="8" width="4" height="4" rx="1"/>'),
};
