import SwiftUI

/// The panel's top filter bar. Deliberately dumb: it shows the visible tabs with
/// counts and reports selection back through a binding — AppModel owns which tabs
/// show, what each means, and how many PRs it holds. Active tab carries the
/// Flexoki blue accent. Scrolls horizontally so enabling every tab never clips.
struct TabBar: View {
    @Binding var selection: PRTab
    var tabs: [PRTab]
    var counts: [PRTab: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Layout.tight) {
                ForEach(tabs) { tab in
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
                    .fixedSize()
                }
            }
            .padding(.horizontal, Layout.roomy)
            .padding(.vertical, Layout.base)
        }
    }
}
