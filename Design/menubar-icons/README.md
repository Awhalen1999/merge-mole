# Menu-bar icons

Source SVGs for the menu-bar status item (the mole-in-a-burrow). These are the
master copies; the app ships them via `MergeMole/Assets.xcassets` as **template
images** (single colour, recoloured by macOS / tinted in code). The `viewBox` is
cropped tight to the artwork (`1.45 1.85 15.1 13.4`, ~0.35 even margin) so the
glyph fills the menu-bar slot like the system icons instead of floating small inside
a padded square. Both states share the same viewBox, so the burrow stays put when
the mole rises.

| File | State | Status |
|------|-------|--------|
| `hole-empty.svg`  | nothing awaiting review | shipped — `Assets.xcassets/HoleEmpty.imageset` |
| `hole-mole-c.svg` | review requested (count beside it) | **shipped** — `Assets.xcassets/HoleMole.imageset` |
| `hole-mole-b.svg` | same, alternate body | kept as a fallback option, not shipped |

Both mole variants share the same dome head, eyes, and burrow ring. The only
difference is where the body starts flaring into the hole:

- **C (shipped):** flare starts low (≈ y11.8) — narrow dome, more burrow visible.
- **B (alternate):** flare starts mid-height (≈ y11) — fuller, fewer gaps.

To switch to B: copy `hole-mole-b.svg` over `Assets.xcassets/HoleMole.imageset/hole-mole.svg`.

Colour is never in the art — the app tints the same template amber/red for the
priority escalation, and prints the PR count as separate text beside it.
