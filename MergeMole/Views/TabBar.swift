import SwiftUI

/// The panel's top filter bar: the visible tabs with counts, reporting selection
/// back through a binding. AppModel owns which tabs show and their counts. The
/// active tab carries the Flexoki blue accent; the row scrolls horizontally when
/// the tabs overflow the panel width.
struct TabBar: View {
    @Binding var selection: PRTab
    var tabs: [PRTab]
    var counts: [PRTab: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Layout.tight) {
                ForEach(tabs) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.vertical, Layout.base)
        }
    }

    private func tabButton(_ tab: PRTab) -> some View {
        let isSelected = selection == tab
        return Button {
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
            .foregroundStyle(isSelected ? Color.appAccent : Color.primary)
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}
