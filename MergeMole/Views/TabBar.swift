import SwiftUI

/// The panel's top filter bar. Deliberately dumb: it shows the tabs with counts
/// and reports selection back through a binding — AppModel owns what each tab
/// means and how many PRs it holds. Active tab carries the Flexoki blue accent.
struct TabBar: View {
    @Binding var selection: PRTab
    var counts: [PRTab: Int]

    var body: some View {
        HStack(spacing: Layout.tight) {
            ForEach(PRTab.allCases) { tab in
                let isSelected = selection == tab
                Button {
                    selection = tab
                } label: {
                    HStack(spacing: Layout.snug) {
                        Text(tab.title)
                        if let count = counts[tab], count > 0 {
                            Text("\(count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(isSelected ? Color.appAccent : .appTextSecondary)
                        }
                    }
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .padding(.horizontal, Layout.base)
                    .padding(.vertical, Layout.tight)
                    .background(
                        isSelected ? Color.appAccent.opacity(0.14) : .clear,
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                    .foregroundStyle(isSelected ? Color.appAccent : .appText)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, Layout.roomy)
        .padding(.vertical, Layout.base)
    }
}
