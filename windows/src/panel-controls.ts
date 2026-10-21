import { el } from "./dom";
import { OPACITY_RANGE, SCALE_RANGE } from "./theme";
import { ValueBar } from "./value-bar";

/** The 투명도 and 크기 bars in one capsule, shown under the header while adjusting. */
export function panelControls(
  opacity: number,
  scale: number,
  onOpacity: (value: number) => void,
  onScale: (value: number) => void,
): HTMLElement {
  return el(
    "div",
    "controls",
    new ValueBar("투명도", OPACITY_RANGE, opacity, onOpacity).element,
    new ValueBar("크기", SCALE_RANGE, scale, onScale).element,
  );
}
