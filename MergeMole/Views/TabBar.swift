import SwiftUI

/// The panel's top filter bar. Deliberately dumb: it shows the visible tabs with
/// counts and reports selection back through a binding — AppModel owns which tabs
/// show, what each means, and how many PRs it holds. Active tab carries the
/// Flexoki blue accent.
///
/// When the tabs overflow the panel width it scrolls horizontally, and a soft
/// fade + chevron appears on whichever side has more — tap it to scroll there.
/// The hint tracks the live scroll position, so it only shows where there's
/// actually more to see.
struct TabBar: View {
    @Binding var selection: PRTab
    var tabs: [PRTab]
    var counts: [PRTab: Int]

    @State private var edges = Edges()
    private struct Edges: Equatable { var leading = false; var trailing = false }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Layout.tight) {
                    ForEach(tabs) { tab in
                        tabButton(tab).id(tab.id)
                    }
                }
                .padding(.horizontal, Layout.roomy)
                .padding(.vertical, Layout.base)
            }
            .onScrollGeometryChange(for: Edges.self) { geo in
                Edges(
                    leading: geo.visibleRect.minX > 4,
                    trailing: geo.visibleRect.maxX < geo.contentSize.width - 4
                )
            } action: { _, new in
                withAnimation(.easeInOut(duration: 0.15)) { edges = new }
            }
            .overlay(alignment: .leading) {
                if edges.leading {
                    scrollHint(.leading) {
                        withAnimation { proxy.scrollTo(tabs.first?.id, anchor: .leading) }
                    }
                }
            }
            .overlay(alignment: .trailing) {
                if edges.trailing {
                    scrollHint(.trailing) {
                        withAnimation { proxy.scrollTo(tabs.last?.id, anchor: .trailing) }
                    }
                }
            }
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
            .foregroundStyle(isSelected ? Color.appAccent : .appText)
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    /// A fade-to-background strip with a chevron at the very edge. The fade is the
    /// visual "there's more" cue; the chevron is the tap target that scrolls there.
    private func scrollHint(_ edge: HorizontalEdge, action: @escaping () -> Void) -> some View {
        let isLeading = edge == .leading
        return ZStack(alignment: isLeading ? .leading : .trailing) {
            // Solid for the first third, then fades — enough to read as "more this
            // way" without burying the edge tab's label.
            LinearGradient(
                stops: [
                    .init(color: Color.appBackground, location: 0),
                    .init(color: Color.appBackground, location: 0.35),
                    .init(color: Color.appBackground.opacity(0), location: 1),
                ],
                startPoint: isLeading ? .leading : .trailing,
                endPoint: isLeading ? .trailing : .leading
            )
            .allowsHitTesting(false)

            Button(action: action) {
                Image(systemName: isLeading ? "chevron.left" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.appTextSecondary)
                    .padding(.horizontal, Layout.snug)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 52)
        .transition(.opacity)
    }
}
