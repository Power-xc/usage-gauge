import { el } from "./dom";
import { shrinkToFit } from "./fit-text";
import { LAYOUT_GLYPHS } from "./layout-glyphs";
import type { LayoutChoice } from "./types";

const MIN_TITLE_SCALE = 0.7;

/** One choice per graph form, slid in under the header: a glyph over a short title, the current one underlined in white. */
export class LayoutPicker {
  readonly element = el("div", "picker");

  constructor(choices: LayoutChoice[], selection: string, choose: (id: string) => void) {
    for (const choice of choices) {
      const glyph = el("span", "choice-glyph");
      glyph.innerHTML = LAYOUT_GLYPHS[choice.id] ?? LAYOUT_GLYPHS.fallback;
      const choiceButton = el("button", "choice", glyph, el("span", "choice-title", choice.title), el("span", "choice-underline"));
      choiceButton.type = "button";
      choiceButton.dataset.layout = choice.id;
      choiceButton.addEventListener("click", () => choose(choice.id));
      this.element.append(choiceButton);
    }
    this.select(selection);
  }

  select(id: string): void {
    for (const choice of this.element.querySelectorAll<HTMLElement>(".choice")) {
      choice.classList.toggle("selected", choice.dataset.layout === id);
    }
  }

  /** Shrinks long titles to their cell; needs the picker to be in the page. */
  fit(): void {
    for (const title of this.element.querySelectorAll<HTMLElement>(".choice-title")) shrinkToFit(title, MIN_TITLE_SCALE);
  }
}
