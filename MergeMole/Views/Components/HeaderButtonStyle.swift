import SwiftUI

/// The panel header's controls (Refresh + the settings menu) share this look: a
/// quiet rounded highlight that fills in on hover and presses a touch darker, in
/// the Flexoki neutral tone. Keeps them feeling tappable and consistent — no bare
/// icons floating in the header.
struct HeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Chrome(configuration: configuration)
    }

    private struct Chrome: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.callout)
                .foregroundStyle(hovering ? Color.appText : .appTextSecondary)
                .padding(.horizontal, Layout.snug)
                .padding(.vertical, Layout.tight)
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
