import SwiftUI
import AppKit

// MergeMole's palette. Text + separators come straight from macOS's semantic system
// colors (`labelColor`, `secondaryLabelColor`, `tertiaryLabelColor`, `separatorColor`)
// — Apple's exact opacities, tracking the system appearance. The page + card fills
// are hand-tuned to match a native System Settings pane: the system's own window /
// control background colors collide on recent macOS (both pure white / #1E1E1E), so
// they'd give no card separation.
//
// Only two things stay bespoke: the brand accent (a fixed blue, reserved for
// interactive + selection state — never status) and the status / tab-identity hues
// (Flexoki), which encode meaning the system palette doesn't. Views reference the
// semantic tokens below, never raw values, so a re-tune touches this one file.

/// Flexoki by Steph Ango (https://stephango.com/flexoki) — the inky status hues.
/// Light mode uses each accent's `600` value, dark mode the `400` (both AA-tuned).
/// Only the stops in use; the neutral ramp is gone now that neutrals are native.
enum Flexoki {
    static let red600:    UInt32 = 0xAF3029, red400:    UInt32 = 0xD14D41
    static let orange600: UInt32 = 0xBC5215, orange400: UInt32 = 0xDA702C
    static let green600:  UInt32 = 0x66800B, green400:  UInt32 = 0x879A39
    // Tab identity hues — which tab, not urgency. Distinct from the brand accent.
    static let blue600:   UInt32 = 0x205EA6, blue400:   UInt32 = 0x4385BE
    static let purple600: UInt32 = 0x5E409D, purple400: UInt32 = 0x8B7EC8
}

private nonisolated func makeNSColor(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green:   CGFloat((hex >> 8) & 0xFF) / 255,
            blue:    CGFloat(hex & 0xFF) / 255,
            alpha: 1)
}

/// One light/dark adaptive `Color` from two hex values. Resolves against whatever
/// appearance it's drawn in, so it follows the system theme for free.
private nonisolated func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? makeNSColor(dark)
            : makeNSColor(light)
    })
}

/// A single fixed `Color`, identical in light + dark — for the brand accent.
private nonisolated func fixed(_ hex: UInt32) -> Color { Color(nsColor: makeNSColor(hex)) }

// MARK: - Semantic tokens (use these in views, not the raw ramp)

private enum Token {
    // Brand accent — a custom vivid blue (#15B0FF), identical in both modes.
    // Interactive emphasis only (primary actions, selection, links); never status.
    static let accent = fixed(0x15B0FF)

    // Page + card fills — hand-tuned (see file header): the native window/control
    // colors collide on recent macOS, so these reproduce a System Settings pane —
    // a light-gray page with white cards (light); a near-black page with a subtly
    // lifted card (dark, ≈ Apple's own +14 lift).
    static let background = adaptive(0xECECEC, 0x1E1E1E)
    static let surface    = adaptive(0xFFFFFF, 0x2C2C2E)

    // Native semantic neutrals — Apple's exact opacities, appearance-tracking.
    static let hairline      = Color(nsColor: .separatorColor)
    static let text          = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary  = Color(nsColor: .tertiaryLabelColor)

    // Status (red/amber/green) + tab-identity (blue/purple) hues — Flexoki.
    static let red    = adaptive(Flexoki.red600,    Flexoki.red400)
    static let amber  = adaptive(Flexoki.orange600, Flexoki.orange400)
    static let green  = adaptive(Flexoki.green600,  Flexoki.green400)
    static let blue   = adaptive(Flexoki.blue600,   Flexoki.blue400)
    static let purple = adaptive(Flexoki.purple600, Flexoki.purple400)
}

/// Declared on `ShapeStyle where Self == Color` (not plain `Color`) so the
/// leading-dot shorthand works everywhere — `.foregroundStyle(.appText)`,
/// `Color.appAccent`, and `tint: Color = .appTextSecondary` all resolve here.
extension ShapeStyle where Self == Color {
    /// Brand accent — #15B0FF. Interactive + selection only — never status.
    static var appAccent: Color        { Token.accent }

    // Neutral interaction fills — one ladder shared across the app so hover,
    // selection, and press read as the same family. Each is the primary ink at a
    // low alpha, layered over whatever sits beneath (clear, a card, the page):
    // hover is the lightest touch, selected the resting "this is on" fill, pressed
    // the deepest. Controls reference these instead of hand-picking opacities.
    static var appFillHover: Color    { Token.text.opacity(0.06) }
    static var appFillSelected: Color { Token.text.opacity(0.12) }
    static var appFillPressed: Color  { Token.text.opacity(0.16) }

    static var appBackground: Color    { Token.background }
    static var appSurface: Color       { Token.surface }
    static var appHairline: Color      { Token.hairline }

    static var appText: Color          { Token.text }
    static var appTextSecondary: Color { Token.textSecondary }
    static var appTextTertiary: Color  { Token.textTertiary }

    // Status spectrum — red / amber / green carry CI, review, and priority. Kept
    // distinct from the accent so it can't be mistaken for urgency.
    static var appRed: Color    { Token.red }
    static var appAmber: Color  { Token.amber }
    static var appGreen: Color  { Token.green }

    // Tab identity hues — the per-tab dots. Not status; they label a tab.
    static var appBlue: Color   { Token.blue }
    static var appPurple: Color { Token.purple }
}
