import { prepareCanvas } from "./canvas";

const COLUMNS = 5;
const ROWS = 7;
/** Dot diameter as a share of the pitch: large enough to read as type, small enough to stay dots. */
const DOT_SHARE = 0.86;
const FULL_TURN = 2 * Math.PI;

/** Digits, "%" and "–" on a 5 × 7 grid, as on an LED display; anything else is left blank. */
const GLYPHS: Record<string, readonly string[]> = {
  "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
  "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
  "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
  "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
  "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
  "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
  "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
  "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
  "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
  "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
  "%": ["11000", "11001", "00010", "00100", "01000", "10011", "00011"],
  "–": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
};

/**
 * Still canvas with `text` in dot-matrix type. `pitch` is the distance between dot centres; a
 * glyph is 5 pitches wide and 7 tall.
 */
export function dotMatrixText(text: string, pitch: number, color: string): HTMLCanvasElement {
  const characters = Array.from(text);
  const width = (characters.length * (COLUMNS + 1) - 1) * pitch;
  const canvas = document.createElement("canvas");
  const context = prepareCanvas(canvas, width, ROWS * pitch);
  const dot = pitch * DOT_SHARE;
  const dots = new Path2D();
  characters.forEach((character, index) => {
    const left = index * (COLUMNS + 1) * pitch;
    GLYPHS[character]?.forEach((line, row) => {
      Array.from(line).forEach((bit, column) => {
        if (bit !== "1") return;
        const x = left + column * pitch + dot / 2;
        const y = row * pitch + dot / 2;
        dots.moveTo(x + dot / 2, y);
        dots.arc(x, y, dot / 2, 0, FULL_TURN);
      });
    });
  });
  context.fillStyle = color;
  context.fill(dots);
  return canvas;
}
