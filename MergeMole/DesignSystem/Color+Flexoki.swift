import SwiftUI
import AppKit

// Flexoki by Steph Ango — https://stephango.com/flexoki — the inky palette
// behind Obsidian. The raw ramp below is here for reference; views should use
// the *semantic* tokens (`.appAccent`, `.appBackground`, …) so a re-tune only
// ever touches this one file.

/// Flexoki raw hex ramp. Light mode uses each accent's `600` value, dark mode
/// the `400` — both tuned by Flexoki for AA contrast on paper / black.
enum Flexoki {
    // Base / ink ramp (warm grays)
    static let paper:   UInt32 = 0xFFFCF0
    static let base50:  UInt32 = 0xF2F0E5
    static let base100: UInt32 = 0xE6E4D9
    static let base150: UInt32 = 0xDAD8CE
    static let base200: UInt32 = 0xCECDC3
    static let base300: UInt32 = 0xB7B5AC
    static let base400: UInt32 = 0x9F9D96
    static let base500: UInt32 = 0x878580
    static let base600: UInt32 = 0x6F6E69
    static let base700: UInt32 = 0x575653
    static let base800: UInt32 = 0x403E3C
    static let base850: UInt32 = 0x343331
    static let base900: UInt32 = 0x282726
    static let base950: UInt32 = 0x1C1B1A
    static let black:   UInt32 = 0x100F0F

    // Accents — 600 (light) / 400 (dark)
    static let red600:     UInt32 = 0xAF3029, red400:     UInt32 = 0xD14D41
    static let orange600:  UInt32 = 0xBC5215, orange400:  UInt32 = 0xDA702C
    static let yellow600:  UInt32 = 0xAD8301, yellow400:  UInt32 = 0xD0A215
    static let green600:   UInt32 = 0x66800B, green400:   UInt32 = 0x879A39
    static let cyan600:    UInt32 = 0x24837B, cyan400:    UInt32 = 0x3AA99F
    static let blue600:    UInt32 = 0x205EA6, blue400:    UInt32 = 0x4385BE
    static let purple600:  UInt32 = 0x5E409D, purple400:  UInt32 = 0x8B7EC8
    static let magenta600: UInt32 = 0xA02F6F, magenta400: UInt32 = 0xCE5D97
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

// MARK: - Semantic tokens (use these in views, not the raw ramp)

/// Each adaptive color resolved once. (Protocol extensions can't hold stored
/// properties, so the tokens below are computed vars backed by these lets.)
private enum Token {
    static let accent        = adaptive(Flexoki.blue600, Flexoki.blue400)
    static let background    = adaptive(Flexoki.paper,   Flexoki.base950)
    static let surface       = adaptive(Flexoki.base50,  Flexoki.base900)
    static let hairline      = adaptive(Flexoki.base150, Flexoki.base850)
    static let text          = adaptive(Flexoki.black,   Flexoki.base200)
    static let textSecondary = adaptive(Flexoki.base600, Flexoki.base500)
    static let textTertiary  = adaptive(Flexoki.base400, Flexoki.base600)
    static let red           = adaptive(Flexoki.red600,    Flexoki.red400)
    static let amber         = adaptive(Flexoki.orange600, Flexoki.orange400)
    static let yellow        = adaptive(Flexoki.yellow600, Flexoki.yellow400)
    static let green         = adaptive(Flexoki.green600,  Flexoki.green400)
}

/// Declared on `ShapeStyle where Self == Color` (not plain `Color`) so the
/// leading-dot shorthand works everywhere — `.foregroundStyle(.appText)`,
/// `Color.appAccent`, and `tint: Color = .appTextSecondary` all resolve here.
extension ShapeStyle where Self == Color {
    /// Brand accent — Flexoki Blue. Reserved for interactive + selection state;
    /// never used for status, so it can't be confused with urgency.
    static var appAccent: Color        { Token.accent }

    static var appBackground: Color    { Token.background }
    static var appSurface: Color       { Token.surface }
    static var appHairline: Color      { Token.hairline }

    static var appText: Color          { Token.text }
    static var appTextSecondary: Color { Token.textSecondary }
    static var appTextTertiary: Color  { Token.textTertiary }

    // Status spectrum — kept distinct from the accent (PLAN: red/amber/green
    // are reserved for CI / review / urgency, not branding).
    static var appRed: Color    { Token.red }
    static var appAmber: Color  { Token.amber }
    static var appYellow: Color { Token.yellow }
    static var appGreen: Color  { Token.green }
}
