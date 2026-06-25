import SwiftUI

/// A single radio option on a surface card — a filled accent radio, a title (with
/// an optional badge), and a one-line detail. The whole card is the hit target.
/// Shared by the onboarding AI step and Settings → Providers so both read alike.
struct RadioCard: View {
    let title: String
    let detail: String
    var badge: String? = nil
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
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .cardSurface()
        }
        .buttonStyle(.plain)
    }
}
