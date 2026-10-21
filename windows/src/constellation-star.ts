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

/** The tools that report something, in the order given. The trail comes from `ProviderView.hourAgo`. */
export function starsOf(providers: ProviderView[]): Star[] {
  const stars: Star[] = [];
  for (const provider of providers) {
    if (provider.message !== null) continue;
    const past = provider.hourAgo;
    const hasTrail = past && (provider.session === null || past.session !== null) && (provider.weekly === null || past.weekly !== null);
    stars.push({
      provider,
      position: unit(provider.session?.remainingPercent ?? null, provider.weekly?.remainingPercent ?? null),
      before: hasTrail ? unit(past.session, past.weekly) : null,
    });
  }
  return stars;
}
