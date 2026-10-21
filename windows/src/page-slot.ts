import { el } from "./dom";
import { enter, leave } from "./motion";
import type { LayoutContent } from "./layouts/types";

/** Where the layout or a tool's page sits; a change of page crossfades with a slight scale, a fresh reading replaces it in place. */
export class PageSlot {
  readonly element = el("div", "grid-slot");
  private key: string | null = null;

  /** Returns whether the page itself changed (not just its numbers). */
  show(key: string, content: LayoutContent): boolean {
    const changed = this.key !== null && this.key !== key;
    const old = this.element.firstElementChild;
    this.key = key;
    if (changed && old instanceof HTMLElement) {
      leave(old, "page");
      this.element.append(content.element);
      enter(content.element, "page");
    } else {
      this.element.replaceChildren(content.element);
    }
    return changed;
  }
}
