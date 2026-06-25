import SwiftUI
import UniformTypeIdentifiers

/// The drag-to-reorder tab list shared by Settings → Tabs and the onboarding
/// Personalize step. Each row is a drag source and drop target (no edit mode),
/// with an identity dot, title + live subtitle, and a visibility checkbox. Reads
/// and writes the shared `AppModel`, so reorders/visibility persist immediately.
/// It draws the rows + edge-to-edge dividers only — wrap it in a surface card.
struct TabReorderList: View {
    @Environment(AppModel.self) private var model
    @State private var dragging: PRTab?

    var body: some View {
        ForEach(Array(model.orderedTabs.enumerated()), id: \.element) { index, tab in
            if index > 0 { Hairline() }
            TabRow(tab: tab,
                   count: model.tabCounts[tab] ?? 0,
                   isOn: visibility(of: tab),
                   dragging: $dragging)
        }
    }

    private func visibility(of tab: PRTab) -> Binding<Bool> {
        Binding(get: { model.visibleTabs.contains(tab) },
                set: { model.setTab(tab, visible: $0) })
    }
}

private struct TabRow: View {
    @Environment(AppModel.self) private var model
    let tab: PRTab
    let count: Int
    @Binding var isOn: Bool
    @Binding var dragging: PRTab?

    var body: some View {
        HStack(spacing: Layout.roomy) {
            DragGrip()
            Circle().fill(tab.dotColor).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(tab.title).font(.callout.weight(.medium)).foregroundStyle(.appText)
                Text(tab.subtitle(count: count)).font(.caption).foregroundStyle(.appTextTertiary)
            }
            Spacer(minLength: Layout.base)
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.checkbox)
        }
        .padding(.horizontal, Layout.roomy)
        .padding(.vertical, Layout.base + 1)
        .contentShape(Rectangle())
        .opacity(dragging == tab ? 0.35 : 1)
        .onDrag {
            dragging = tab
            return NSItemProvider(object: tab.rawValue as NSString)
        }
        .onDrop(of: [.text], delegate: TabDropDelegate(target: tab, model: model, dragging: $dragging))
    }
}

/// The six-dot reorder affordance.
private struct DragGrip: View {
    var body: some View {
        Grid(horizontalSpacing: 2.5, verticalSpacing: 2.5) {
            ForEach(0..<3, id: \.self) { _ in
                GridRow { dot; dot }
            }
        }
        .foregroundStyle(.appTextTertiary)
    }
    private var dot: some View { Circle().frame(width: 2.5, height: 2.5) }
}

/// Live reorder: as a dragged row passes over another, slot it into that place.
/// SwiftUI invokes drop callbacks on the main thread, so the model touches are
/// bridged with `assumeIsolated`.
private struct TabDropDelegate: DropDelegate {
    let target: PRTab
    let model: AppModel
    @Binding var dragging: PRTab?

    nonisolated func dropEntered(info: DropInfo) {
        MainActor.assumeIsolated {
            guard let dragging, dragging != target else { return }
            model.moveTab(dragging, to: target)
        }
    }
    nonisolated func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    nonisolated func performDrop(info: DropInfo) -> Bool {
        MainActor.assumeIsolated { dragging = nil }
        return true
    }
}
