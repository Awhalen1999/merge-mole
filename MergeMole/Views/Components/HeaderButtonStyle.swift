import SwiftUI

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
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6))
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }

        private var background: Color {
            if configuration.isPressed { return Color.appText.opacity(0.14) }
            if hovering { return Color.appText.opacity(0.08) }
            return .clear
        }
    }
}
