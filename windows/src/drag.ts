import { bridge } from "./bridge";

/** How far the pointer has to move with the button down before it counts as a drag rather than a click. */
const DRAG_DISTANCE = 4;

/** Dragging inside `area` moves the window; a plain click still reaches what is under the pointer. */
export function makeDraggable(area: HTMLElement): void {
  area.addEventListener("mousedown", (event) => {
    if (event.button !== 0 || (event.target as HTMLElement).closest("button")) return;
    const { clientX, clientY } = event;
    const stop = (): void => {
      window.removeEventListener("mousemove", move);
      window.removeEventListener("mouseup", stop);
    };
    const move = (next: MouseEvent): void => {
      if (Math.hypot(next.clientX - clientX, next.clientY - clientY) < DRAG_DISTANCE) return;
      stop();
      void bridge.startDragging();
    };
    window.addEventListener("mousemove", move);
    window.addEventListener("mouseup", stop);
  });
}
