export interface Point {
  x: number;
  y: number;
}

export function pointAt(center: Point, radius: number, angle: number): Point {
  return { x: center.x + Math.cos(angle) * radius, y: center.y + Math.sin(angle) * radius };
}

/** Deterministic 0..<1 value for a seed, so shapes stay put from frame to frame. */
export function noise(seed: number): number {
  const value = Math.sin(seed * 12.9898 + 78.233) * 43758.5453;
  return value - Math.floor(value);
}

let panelScale = 1;

/** The panel is shown scaled by a CSS transform; canvases made afterwards get that many more pixels so they stay crisp. */
export function setPanelScale(scale: number): void {
  panelScale = scale;
}

/** Sizes a canvas for the device pixel ratio and panel scale and returns a context drawing in CSS pixels. */
export function prepareCanvas(canvas: HTMLCanvasElement, width: number, height: number): CanvasRenderingContext2D {
  const scale = (window.devicePixelRatio || 1) * panelScale;
  canvas.width = Math.round(width * scale);
  canvas.height = Math.round(height * scale);
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;
  const context = canvas.getContext("2d");
  if (!context) throw new Error("Canvas 2D is not available");
  context.scale(scale, scale);
  return context;
}
