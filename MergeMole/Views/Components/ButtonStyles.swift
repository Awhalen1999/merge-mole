import SwiftUI

// The panel's button looks, all on the shared `controlRadius` corner with the same
// hover/press timing so they read as one family:
//   • HeaderButtonStyle    — ghosted, for header controls
//   • ProminentButtonStyle — accent-filled, the primary call to action
//   • SecondaryButtonStyle — outlined neutral, a quieter action ("Try again")

/// The panel header's controls (Refresh + the settings menu) share this look: a
/// quiet rounded highlight that fills in on hover and presses a touch darker, in
/// the Flexoki neutral tone. Keeps them feeling tappable and consistent — no bare
/// icons floating in the header.
struct HeaderButtonStyle: ButtonStyle {
    /// A square icon button (the settings menu) rather than a text pill — same
    /// height as the others, with equal width so it reads as a tidy square.
    var square = false

    func makeBody(configuration: Configuration) -> some View {
        Chrome(configuration: configuration, square: square)
    }

    private struct Chrome: View {
        let configuration: ButtonStyleConfiguration
        let square: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.callout)
                .foregroundStyle(hovering ? Color.appText : .appTextSecondary)
                // One shared height keeps every header button level; a square
                // button takes a matching minWidth so it comes out a clean square.
                .frame(height: Layout.controlHeight)
                .frame(minWidth: square ? Layout.controlHeight : nil)
                .padding(.horizontal, square ? 0 : Layout.snug)
                .background(
                    background,
                    in: RoundedRectangle(cornerRadius: Layout.controlRadius)
                )
                .contentShape(RoundedRectangle(cornerRadius: Layout.controlRadius))
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }

        private var background: Color {
            if configuration.isPressed { return Color.appFillPressed }
            if hovering { return Color.appFillHover }
            return .clear
        }
    }
}

/// The filled call-to-action (e.g. "Connect GitHub"): the accent on a rounded
/// rect that matches the header buttons' corner radius. Brightens a touch on
/// hover and darkens on press — the same restrained chrome as `HeaderButtonStyle`,
/// just solid instead of ghosted.
struct ProminentButtonStyle: ButtonStyle {
    /// Fill the available width (the default — a full-width CTA). Pass `false` for an
    /// inline pill that hugs its label (e.g. a wizard's trailing "Continue").
    var fillWidth = true

    func makeBody(configuration: Configuration) -> some View {
        Chrome(configuration: configuration, fillWidth: fillWidth)
    }

    private struct Chrome: View {
        let configuration: ButtonStyleConfiguration
        var fillWidth = true
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, Layout.base)
                .padding(.horizontal, Layout.roomy)
                .frame(maxWidth: fillWidth ? .infinity : nil)
                .background {
                    RoundedRectangle(cornerRadius: Layout.controlRadius)
                        .fill(Color.appAccent)
                        .overlay(scrim, in: RoundedRectangle(cornerRadius: Layout.controlRadius))
                }
                .contentShape(RoundedRectangle(cornerRadius: Layout.controlRadius))
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
                .opacity(isEnabled ? 1 : 0.45)   // dim when disabled (custom styles don't by default)
        }

        /// A thin scrim over the accent: white to lift on hover, black to seat on press.
        private var scrim: Color {
            if configuration.isPressed { return .black.opacity(0.16) }
            if hovering { return .white.opacity(0.14) }
            return .clear
        }
    }
}

/// A quieter, outlined action — surface fill, hairline border, primary-ink label
/// (e.g. "Try again" in the error state). Same corner and timing as the others.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Chrome(configuration: configuration)
    }

    private struct Chrome: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.callout.weight(.medium))
                .foregroundStyle(.appText)
                .padding(.vertical, Layout.base)
                .padding(.horizontal, Layout.roomy)
                // Surface base, then the shared neutral fill ladder composited on
                // top for hover/press — same feedback as the ghost + header buttons,
                // just over a card instead of clear.
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: Layout.controlRadius))
                .overlay(highlight, in: RoundedRectangle(cornerRadius: Layout.controlRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.controlRadius)
                        .strokeBorder(Color.appHairline, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: Layout.controlRadius))
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }

        private var highlight: Color {
            if configuration.isPressed { return Color.appFillPressed }
            if hovering { return Color.appFillHover }
            return .clear
        }
    }
}

/// The panel's top filter tabs (Created / Assigned / …). A selected tab rests on a
/// quiet neutral pill; an unselected tab fills to a *softer* version of that on
/// hover; either deepens on press. Same neutral ladder and 0.12s timing as the
/// header buttons, so the whole top bar reacts as one family. The label (title,
/// count, weight) stays with the view — this owns only the pill chrome.
struct TabPillButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        Chrome(configuration: configuration, isSelected: isSelected)
    }

    private struct Chrome: View {
        let configuration: ButtonStyleConfiguration
        let isSelected: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .padding(.horizontal, Layout.base)
                .padding(.vertical, Layout.tight)
                .background(fill, in: RoundedRectangle(cornerRadius: Layout.controlRadius))
                .contentShape(RoundedRectangle(cornerRadius: Layout.controlRadius))
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }

        // Selection is the resting fill; an idle unselected tab is bare and only
        // lifts to the soft hover tint. A press deepens either to the same step.
        private var fill: Color {
            if configuration.isPressed { return Color.appFillPressed }
            if isSelected { return Color.appFillSelected }
            return hovering ? Color.appFillHover : .clear
        }
    }
}
