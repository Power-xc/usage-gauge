import { Glide } from "./glide";

/** Numbers that ease towards their targets together; a target of null (no value) stays null. */
export class GlideSet {
  readonly glides: Glide[];

  constructor(private readonly targets: readonly (number | null)[]) {
    this.glides = targets.map((target) => {
      const glide = new Glide();
      glide.to(target ?? 0);
      return glide;
    });
  }

  get values(): (number | null)[] {
    return this.glides.map((glide, index) => (this.targets[index] === null ? null : glide.value));
  }
}
