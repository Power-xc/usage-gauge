const PAGE_MS = 300;
const VALUE_MS = 500;
const REDUCED_MS = 150;
const PAGE_SCALE = 0.98;
const ENTER_OFFSET = 6;
const EASING = "ease-in-out";

/** Users who ask the system for less motion get short, plain fades instead of scale and slide. */
export const isReducedMotion = (): boolean => window.matchMedia("(prefers-reduced-motion: reduce)").matches;

export const pageMilliseconds = (): number => (isReducedMotion() ? REDUCED_MS : PAGE_MS);
export const valueMilliseconds = (): number => (isReducedMotion() ? REDUCED_MS : VALUE_MS);

/** Ease in and out, close to CSS `ease-in-out`. */
export const easeInOut = (progress: number): number => progress * progress * (3 - 2 * progress);

let currentFrame = 0;

/** The animation clock of the frame being drawn; the page timeline, so it keeps running where `performance.now` is stubbed. */
export function beginFrame(): number {
  currentFrame = document.timeline.currentTime === null ? performance.now() : Number(document.timeline.currentTime);
  return currentFrame;
}

export const frameTime = (): number => currentFrame;

/** Fades a node in; pages also grow from a slightly smaller size at the top, and sections slide down a little. */
export function enter(node: HTMLElement, kind: "page" | "section"): void {
  const from: Keyframe = { opacity: 0 };
  if (!isReducedMotion()) {
    from.transform = kind === "page" ? `scale(${PAGE_SCALE})` : `translateY(-${ENTER_OFFSET}px)`;
  }
  node.animate([from, { opacity: 1, transform: "none" }], { duration: pageMilliseconds(), easing: EASING });
}

/**
 * Fades a node out on top of what replaces it, then removes it. It is taken out of the flow
 * first, so the panel can already settle at its new size.
 */
export function leave(node: HTMLElement, kind: "page" | "section"): void {
  const { offsetTop, offsetLeft, offsetWidth } = node;
  node.style.cssText += `;position:absolute;top:${offsetTop}px;left:${offsetLeft}px;width:${offsetWidth}px;pointer-events:none`;
  const to: Keyframe = { opacity: 0 };
  if (!isReducedMotion()) {
    to.transform = kind === "page" ? `scale(${PAGE_SCALE})` : `translateY(-${ENTER_OFFSET}px)`;
  }
  const fade = node.animate([{ opacity: 1, transform: "none" }, to], { duration: pageMilliseconds(), easing: EASING, fill: "forwards" });
  fade.finished.then(() => node.remove(), () => node.remove());
}
