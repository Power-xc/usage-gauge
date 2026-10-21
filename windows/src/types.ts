/** How urgent a remaining allowance is; mirrors the Rust `UsageLevel`. */
export type UsageLevel = "comfortable" | "low" | "critical";

/** The panel's look; mirrors the Rust `PanelStyle`. */
export type PanelStyle = "iris" | "dot" | "mono";

/** How the panel arranges the tools; mirrors the Rust `PanelLayout`. */
export type PanelLayout = "dial" | "bars" | "columns" | "figures";

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

export interface ProviderView {
  id: string;
  title: string;
  plan: string | null;
  session: WindowView | null;
  weekly: WindowView | null;
  /** Why the provider is not connected; null while it has readings. */
  message: string | null;
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
