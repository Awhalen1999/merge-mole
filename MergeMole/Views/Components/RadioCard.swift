import SwiftUI

/// A single radio option on a surface card — a filled accent radio, a title (with
/// an optional badge), and a one-line detail. An optional warning renders inside
/// the card when the option can't currently work. The option row is the hit target.
///
/// An option that needs configuration passes `expansion`: it renders inside the
/// same card, under a divider, while the option is selected — the card grows and
/// shrinks with the choice instead of spawning a sibling box. Expansion content
/// is full-bleed (so row lists keep edge-to-edge hairlines); pad forms at the
/// call site. Used by Settings → Providers, Settings → Unread's onboarding twin,
/// and the wizard's AI step.
struct RadioCard<Expansion: View>: View {
    let title: String
    let detail: String
    let badge: String?
    let warning: String?
    let selected: Bool
    let action: () -> Void
    private let expansion: (() -> Expansion)?

    init(title: String, detail: String, badge: String? = nil, warning: String? = nil,
         selected: Bool, action: @escaping () -> Void,
         @ViewBuilder expansion: @escaping () -> Expansion) {
        self.title = title
        self.detail = detail
        self.badge = badge
        self.warning = warning
        self.selected = selected
        self.action = action
        self.expansion = expansion
    }

    /// A plain option with no inline configuration.
    init(title: String, detail: String, badge: String? = nil, warning: String? = nil,
         selected: Bool, action: @escaping () -> Void) where Expansion == EmptyView {
        self.title = title
        self.detail = detail
        self.badge = badge
        self.warning = warning
        self.selected = selected
        self.action = action
        self.expansion = nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                .padding(Layout.roomy)   // the inset cardSurface(padded:) would add
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if selected, let expansion {
                Group {
                    Hairline()
                    expansion()
                }
                .transition(.opacity)
            }
        }
        .cardSurface(padded: false)
    }
}
