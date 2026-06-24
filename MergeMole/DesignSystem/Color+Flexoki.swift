import SwiftUI
import AppKit

// Flexoki by Steph Ango — https://stephango.com/flexoki — the inky palette behind
// Obsidian, carrying the warm neutrals + status hues. Views should reference the
// *semantic* tokens (`.appAccent`, `.appBackground`, …) so a re-tune only ever
// touches this one file. The raw ramp is trimmed to the stops actually in use.

/// Flexoki raw hex ramp. Light mode uses each accent's `600` value, dark mode the
/// `400` — both tuned by Flexoki for AA contrast on paper / black.
enum Flexoki {
    // Base / ink ramp (warm grays) — only the stops the app actually uses.
    static let paper:   UInt32 = 0xFFFCF0
    static let base50:  UInt32 = 0xF2F0E5
    static let base150: UInt32 = 0xDAD8CE
    static let base200: UInt32 = 0xCECDC3
    static let base400: UInt32 = 0x9F9D96
    static let base500: UInt32 = 0x878580
    static let base600: UInt32 = 0x6F6E69
    static let base850: UInt32 = 0x343331
    static let base900: UInt32 = 0x282726
    static let base950: UInt32 = 0x1C1B1A
    static let black:   UInt32 = 0x100F0F

    // Status accents — 600 (light) / 400 (dark). The brand blue is intentionally
    // *not* here: it's a custom hue, defined on `Token.accent`.
    static let red600:    UInt32 = 0xAF3029, red400:    UInt32 = 0xD14D41
    static let orange600: UInt32 = 0xBC5215, orange400: UInt32 = 0xDA702C
    static let green600:  UInt32 = 0x66800B, green400:  UInt32 = 0x879A39
}

private nonisolated func makeNSColor(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green:   CGFloat((hex >> 8) & 0xFF) / 255,
            blue:    CGFloat(hex & 0xFF) / 255,
            alpha: 1)
}

/// One light/dark adaptive `Color` from two Flexoki hex values. Resolves against
/// whatever appearance it's drawn in, so it follows the system theme for free.
private nonisolated func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? makeNSColor(dark)
            : makeNSColor(light)
    })
}

/// A single fixed `Color`, identical in light + dark — for the brand accent, a
/// deliberate hue rather than a theme-derived neutral.
private nonisolated func fixed(_ hex: UInt32) -> Color { Color(nsColor: makeNSColor(hex)) }

// MARK: - Semantic tokens (use these in views, not the raw ramp)

/// Each color resolved once. (Protocol extensions can't hold stored properties, so
/// the tokens below are computed vars backed by these lets.)
private enum Token {
    /// Brand accent — a custom vivid blue (#15B0FF), the same in both modes.
    static let accent        = fixed(0x15B0FF)
    static let background    = adaptive(Flexoki.paper,   Flexoki.base950)
    static let surface       = adaptive(Flexoki.base50,  Flexoki.base900)
    static let hairline      = adaptive(Flexoki.base150, Flexoki.base850)
    static let text          = adaptive(Flexoki.black,   Flexoki.base200)
    static let textSecondary = adaptive(Flexoki.base600, Flexoki.base500)
    static let textTertiary  = adaptive(Flexoki.base400, Flexoki.base600)
    static let red           = adaptive(Flexoki.red600,    Flexoki.red400)
    static let amber         = adaptive(Flexoki.orange600, Flexoki.orange400)
    static let green         = adaptive(Flexoki.green600,  Flexoki.green400)
}

/// Declared on `ShapeStyle where Self == Color` (not plain `Color`) so the
/// leading-dot shorthand works everywhere — `.foregroundStyle(.appText)`,
/// `Color.appAccent`, and `tint: Color = .appTextSecondary` all resolve here.
extension ShapeStyle where Self == Color {
    /// Brand accent — #15B0FF. Reserved for interactive + selection state only —
    /// never status, so it can't be mistaken for urgency.
    static var appAccent: Color        { Token.accent }

    static var appBackground: Color    { Token.background }
    static var appSurface: Color       { Token.surface }
    static var appHairline: Color      { Token.hairline }

    static var appText: Color          { Token.text }
    static var appTextSecondary: Color { Token.textSecondary }
    static var appTextTertiary: Color  { Token.textTertiary }

    // Status spectrum — kept distinct from the accent (red / amber / green carry
    // CI, review, and the mono→amber→red escalation; the accent stays out of it).
    static var appRed: Color    { Token.red }
    static var appAmber: Color  { Token.amber }
    static var appGreen: Color  { Token.green }
}
