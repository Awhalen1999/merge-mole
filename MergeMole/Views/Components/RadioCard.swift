import SwiftUI

/// A single radio option on a surface card — a filled accent radio, a title (with
/// an optional badge), and a one-line detail. An optional warning renders inside
/// the card when the option can't currently work. The whole card is the hit target.
/// Used by Settings → Providers for the AI-mode options.
struct RadioCard: View {
    let title: String
    let detail: String
    var badge: String? = nil
    var warning: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Layout.roomy) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.appAccent : .appTextTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Layout.snug) {
                        Text(title).font(.callout.weight(.semibold)).foregroundStyle(.appText)
                        if let badge { Pill(badge, tint: .appAccent) }
                    }
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let warning {
                        InlineStatus(kind: .error(warning))
                            .padding(.top, Layout.snug)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .cardSurface()
        }
        .buttonStyle(.plain)
    }
}
