import type { Point } from "./canvas";
import type { ProviderView } from "./types";

/**
 * One tool as a point on the constellation field: x is its short window's remaining share and y
 * its long window's, both as 0...1 with y growing upward. A tool with a single window sits on the
 * axis of that window.
 */
export interface Star {
  provider: ProviderView;
  position: Point;
  /** Where the tool stood about an hour ago; null without history that far back. */
  before: Point | null;
}

const unit = (short: number | null, long: number | null): Point => ({ x: (short ?? 0) / 100, y: (long ?? 0) / 100 });

/** The tools that report something, in the order given. The trail comes from `ProviderView.hourAgo`, which the backend sets only when every window of the tool has a past share. */
export function starsOf(providers: ProviderView[]): Star[] {
  const stars: Star[] = [];
  for (const provider of providers) {
    if (provider.message !== null) continue;
    const past = provider.hourAgo;
    stars.push({
      provider,
      position: unit(provider.session?.remainingPercent ?? null, provider.weekly?.remainingPercent ?? null),
      before: past ? unit(past.session, past.weekly) : null,
    });
  }
  return stars;
}
