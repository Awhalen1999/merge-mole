import SwiftUI

/// A compact inline status line — a leading spinner / ✓ / ✗ plus a short message.
/// Used by the connect + verify flows in Settings. Errors use the
/// app's failure color (red, matching every other failure cue); progress and
/// success read quiet so they don't shout.
struct InlineStatus: View {
    enum Kind { case progress(String), ok(String), error(String) }
    let kind: Kind

    var body: some View {
        HStack(spacing: Layout.snug) {
            switch kind {
            case .progress(let message):
                ProgressView().controlSize(.small)
                Text(message).foregroundStyle(.appTextSecondary)
            case .ok(let message):
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.appGreen)
                Text(message).foregroundStyle(.appTextSecondary)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.appRed)
                Text(message).foregroundStyle(.appTextSecondary)
            }
        }
        .font(.caption)
    }
}

/// The persisted outcome of a connect/verify action. The transient `.progress`
/// state is driven by a separate in-flight flag, so it isn't stored here.
enum InlineFeedback: Equatable {
    case ok(String)
    case error(String)
}
