/** Scales a label down, at most to `minScale`, until it fits its parent's width; like SwiftUI's minimumScaleFactor. */
export function shrinkToFit(node: HTMLElement, minScale: number): void {
  node.style.transform = "";
  const room = node.parentElement?.clientWidth ?? 0;
  if (room === 0 || node.scrollWidth <= room) return;
  node.style.transform = `scale(${Math.max(minScale, room / node.scrollWidth)})`;
}
