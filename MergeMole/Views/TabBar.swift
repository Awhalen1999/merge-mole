import SwiftUI

/// The panel's top filter bar: the visible tabs with counts, reporting selection
/// back through a binding. AppModel owns which tabs show and their counts. The
/// active tab rests on a quiet neutral pill and unselected tabs lift on hover; the
/// row scrolls horizontally when the tabs overflow the panel width.
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
                        .foregroundStyle(isSelected ? .appText : .appTextSecondary)
                }
            }
            // Selection is white + bold — never an accent fill. Blue is the brand
            // color, but a blue selected tab reads cheap here; the neutral pill and
            // its hover/press chrome live in TabPillButtonStyle.
            .font(.callout.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(.appText)
        }
        .buttonStyle(TabPillButtonStyle(isSelected: isSelected))
        .fixedSize()
    }
}
