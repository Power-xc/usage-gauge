/** How urgent a remaining allowance is; mirrors the Rust `UsageLevel`. */
export type UsageLevel = "comfortable" | "low" | "critical";

/** The panel's look; mirrors the Rust `PanelStyle`. */
export type PanelStyle = "iris" | "dot" | "mono";

/** How the panel arranges the tools; mirrors the Rust `PanelLayout`. */
export type PanelLayout =
  | "dial"
  | "bars"
  | "columns"
  | "figures"
  | "orbit"
  | "capsule"
  | "constellation"
  | "ruler"
  | "trend"
  | "histogram"
  | "spark"
  | "burst";

/** One rate-limit window, already resolved and formatted by the backend. */
export interface WindowView {
  displayPercent: number;
  remainingPercent: number;
  /** 0...1 share of the window that has passed; null hides the rim clock. */
  elapsedFraction: number | null;
  label: string;
  countdown: string;
  /** Terse form for the monospaced styles, e.g. "3h 50m". */
  countdownCompact: string;
  level: UsageLevel;
}

/** One reading of a window's remaining share; `at` is epoch milliseconds. */
export interface HistoryPoint {
  at: number;
  remaining: number;
}

/** Remaining % per slice of the spark strip, for each style's bar pitch. */
export interface SparkSlices {
  iris: (number | null)[];
  dot: (number | null)[];
  mono: (number | null)[];
}

/** How a provider's short window (its long one when that is the only one) drained in its current period. Times are epoch milliseconds. */
export interface HistoryView {
  now: number;
  periodStart: number | null;
  periodEnd: number | null;
  points: HistoryPoint[];
  /** Too little recorded to draw a chart. */
  isRecording: boolean;
  /** % per hour over the last 60 min; null without enough data or use. */
  burnRate: number | null;
  /** Null when the allowance lasts past the reset. */
  projectedEmpty: number | null;
  /** % used per histogram column and per burst ray; null after now. */
  usedSlices: (number | null)[];
  burstSlices: (number | null)[];
  remainingSlices: SparkSlices;
}

export interface ProviderView {
  id: string;
  title: string;
  plan: string | null;
  session: WindowView | null;
  weekly: WindowView | null;
  /** Why the provider is not connected; null while it has readings. */
  message: string | null;
  /**
   * Remaining percent of each window about an hour ago, from the recorded usage history. The
   * constellation draws a trail from there when it is present; absent until history is recorded.
   */
  hourAgo?: HourAgo | null;
  history: HistoryView | null;
}

/** Where a tool stood an hour ago; null for a window without a sample that far back. */
export interface HourAgo {
  session: number | null;
  weekly: number | null;
}

export interface UsageView {
  providers: ProviderView[];
  /** Epoch milliseconds of the oldest provider reading; null before the first fetch. */
  measuredAt: number | null;
}

export interface PanelState {
  usage: UsageView;
  opacity: number;
  isShown: boolean;
  /** Whether the system blur is active behind the window; without it the smoke is denser. */
  hasGlass: boolean;
  style: PanelStyle;
  layout: PanelLayout;
  /** Panel size factor, 0.7...1.6. */
  scale: number;
}
