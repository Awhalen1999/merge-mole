import SwiftUI

/// The one layout every full-panel state uses — connect, error, all-caught-up.
/// A vertically-centered column: icon, title, message, then caller-supplied
/// actions and an optional footnote, capped to a comfortable measure. Keeping
/// them identical is what makes the empty states feel like one consistent app.
///
/// The icon is a `@ViewBuilder` so a state can use a `StatusIcon` disc or, like
/// the connect screen, the bare brand glyph. Actions own their top padding, so a
/// state with none (e.g. caught-up) leaves no phantom gap.
struct StatusScreen<Icon: View, Actions: View>: View {
    let title: String
    let message: String
    var footnote: String? = nil
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Layout.generous)

            icon()

            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.appText)
                .padding(.top, Layout.roomy)

            Text(message)
                .font(.callout)
                .foregroundStyle(.appTextSecondary)
                .frame(maxWidth: 300)
                .padding(.top, Layout.snug)

            actions()

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.appTextTertiary)
                    .padding(.top, Layout.roomy)
            }

            Spacer(minLength: Layout.generous)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Layout.margin)
        .multilineTextAlignment(.center)
    }
}

/// A status glyph seated in a soft tinted disc — the shared icon treatment for the
/// error and caught-up states (the connect screen uses the bare brand glyph).
struct StatusIcon: View {
    let systemName: String
    var tint: Color = .appTextSecondary

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 56, height: 56)
            .background(tint.opacity(0.12), in: Circle())
    }
}

#Preview("Error") {
    StatusScreen(
        title: "Couldn't reach GitHub",
        message: "The request timed out while fetching your pull requests. Check your connection and try again.",
        footnote: "last synced 6m ago"
    ) {
        StatusIcon(systemName: "exclamationmark", tint: .appRed)
    } actions: {
        Button { } label: { Label("Try again", systemImage: "arrow.clockwise") }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, Layout.generous)
    }
    .frame(width: 400, height: 600)
    .background(Color.appBackground)
}

#Preview("Caught up") {
    StatusScreen(
        title: "All caught up",
        message: "No pull requests need your attention in Review Requested."
    ) {
        StatusIcon(systemName: "checkmark", tint: .appGreen)
    } actions: {
        EmptyView()
    }
    .frame(width: 400, height: 600)
    .background(Color.appBackground)
}
