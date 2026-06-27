# Style

MergeMole's visual conventions: color, type, spacing. The goal is a **native-macOS
app** — System-Settings-grade neutrals and controls with one brand accent. Color is
used sparingly and only where it means something. The app follows the **system
appearance** (no in-app theme switch); every token is light/dark adaptive.

Two rules underpin everything:

1. **Tokens, not raw values.** Views reference semantic names, never hex or numbers,
   so a re-tune touches one file.
2. **Color means something.** The accent means "interactive/selected." Status hues
   mean CI/review/priority. Identity hues label a tab. Nothing is decorative.

---

## Color

Defined in `MergeMole/DesignSystem/Color+Flexoki.swift`. Reference via the
`.appXxx` accessors (e.g. `.foregroundStyle(.appText)`), never the raw hex.

### Brand accent

| Token | Value | Use |
|---|---|---|
| `.appAccent` | `#15B0FF` (fixed, identical light + dark) | Interactive + selection **only** — primary buttons, links, the AI radio, the logo. Never status, never a decorative fill. |

System controls (checkboxes, toggles, the selected Settings tab) inherit the accent
through the Settings `TabView` tint.

### Neutrals — native semantic colors

Text and separators map straight to macOS semantic colors, so they track the system
appearance with Apple's exact opacities.

| Token | Source |
|---|---|
| `.appText` | `labelColor` |
| `.appTextSecondary` | `secondaryLabelColor` |
| `.appTextTertiary` | `tertiaryLabelColor` |
| `.appHairline` | `separatorColor` |

### Page + card fills — hand-tuned

The system's own window/control background colors collide on recent macOS (both pure
white / near-black), giving no card separation. So these are tuned by hand to
reproduce a System Settings pane — a light-gray page with white cards.

| Token | Light | Dark |
|---|---|---|
| `.appBackground` (page) | `#ECECEC` | `#1E1E1E` |
| `.appSurface` (card) | `#FFFFFF` | `#2C2C2E` |

### Status + identity hues — Flexoki

[Flexoki](https://stephango.com/flexoki) inky hues. Light mode uses each accent's
`600` value, dark mode the `400` (both AA-tuned).

| Token | Meaning |
|---|---|
| `.appRed` | Failure / blocking (CI failed, urgent priority, destructive actions) |
| `.appAmber` | Caution (high priority, the mono→amber→red escalation) |
| `.appGreen` | Success / healthy (CI passing, connected) |
| `.appBlue` | Tab **identity** dot (not status) |
| `.appPurple` | Tab **identity** dot (not status) |

Notes:
- **Priority only colors high/urgent** (amber/red). Low/normal stay quiet — the list
  is already priority-sorted, so coloring everything would be noise.
- **Identity ≠ status.** The per-tab dots (blue/purple/green/amber/etc.) label *which*
  tab; they're deliberately distinct from the accent (which only ever means selection).
  The "All" tab is the superset rather than a category, so it takes the neutral
  primary dot (`.appText`).

---

## Type

Native macOS text styles — a clean built-in hierarchy, **no custom point sizes**. This
keeps the app legible at every Dynamic Type setting and matches the system feel.

| Style | Where |
|---|---|
| `.title2` (`.bold` / `.semibold`) | Screen / hero headings |
| `.title3`, `.headline` | Section / card titles |
| `.callout` | Default row label and body text. `.weight(.medium)` for a row title, `.weight(.semibold)` for a selected/emphasized one |
| `.caption` | Secondary / subtitle lines |
| `.caption2` | The smallest labels. Uppercase section headers are `.caption2.weight(.semibold).tracking(0.6)` in `.appTextTertiary` |

Monospaced variants for anything that should read as data:
- `.body.monospaced()` — token / key entry fields
- `.caption.monospaced()` — GitHub scopes
- `.caption2.monospacedDigit()` / `.monospacedDigit()` — counts and the menu-bar badge,
  so digits don't shift width as numbers change

---

## Spacing & radius

Defined in `MergeMole/DesignSystem/Layout.swift`. One scale tunes the app's density;
views use the names, never raw numbers, so the rhythm stays even.

| Token | Value | Use |
|---|---|---|
| `Layout.hair` | 2 | Around hairlines |
| `Layout.tight` | 4 | Within a tight group |
| `Layout.snug` | 6 | Between pills |
| `Layout.base` | 8 | Between rows / sections |
| `Layout.roomy` | 12 | Card padding, list gaps |
| `Layout.generous` | 16 | Airier outer margin for the sectioned list |
| `Layout.margin` | = `generous` (16) | The panel's left/right margin — header, tab bar, and card content all align to it |

Fixed dimensions:

| Token | Value | Use |
|---|---|---|
| `Layout.cardRadius` | 10 | Card corner radius |
| `Layout.controlRadius` | 6 | Header control corner radius |
| `Layout.controlHeight` | 24 | Shared header-button height |
| `Layout.headerHeight` | 48 | The panel's top bar |
| `Layout.accentBar` | 3 | A card's priority edge-bar width |

---

## Shared surfaces

To stop two screens from drifting apart, the chrome is built once and reused:

- **`.cardSurface(padded:)`** (`Views/Components/Surface.swift`) — the single modifier
  that builds *every* card: `appSurface` fill, hairline border, `cardRadius`. Pass
  `padded: false` for full-bleed row lists whose dividers run edge-to-edge.
- **`TabSettingRow`** (`Views/Components/TabReorderList.swift`) — one row (identity dot
  + title + subtitle + trailing control) shared by Settings → Tabs and → Menu-bar count.
- **`InlineStatus`**, **`RadioCard`**, **`AppIconTile`**, **`BrandMark`** — shared pieces
  so connect/verify flows, AI options, and the brand mark look identical everywhere.
