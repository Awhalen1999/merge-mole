import SwiftUI
import UniformTypeIdentifiers

/// The drag-to-reorder tab list for Settings → Tabs. Each row is a drag source and
/// drop target (no edit mode), with an identity dot, title + subtitle, and a
/// visibility checkbox. Custom tabs also carry a pencil that opens their editor
/// (via `onEdit` — the sheet lives with the Settings pane). Reads and writes the
/// shared `AppModel`, so reorders/visibility persist immediately.
/// It draws the rows + edge-to-edge dividers only — wrap it in a surface card.
struct TabReorderList: View {
    @Environment(AppModel.self) private var model
    @State private var dragging: PRTab?
    /// Called with a custom tab's definition when its pencil is clicked.
    var onEdit: (CustomTab) -> Void

    var body: some View {
        ForEach(Array(model.orderedTabs.enumerated()), id: \.element) { index, tab in
            if index > 0 { Hairline() }
            TabRow(tab: tab, isOn: visibility(of: tab), dragging: $dragging, onEdit: onEdit)
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
    @Binding var isOn: Bool
    @Binding var dragging: PRTab?
    var onEdit: (CustomTab) -> Void

    /// This tab's saved definition when it's a custom one — drives the mono
    /// query subtitle and the edit pencil in a single check.
    private var customTab: CustomTab? {
        if case .custom(let id) = tab { return model.customTab(id) }
        return nil
    }

    var body: some View {
        TabSettingRow(title: model.title(for: tab),
                      dotColor: tab.dotColor,
                      subtitle: model.subtitle(for: tab),
                      monoSubtitle: customTab != nil,
                      leading: { DragGrip() }) {
            if let customTab {
                Button { onEdit(customTab) } label: {
                    Image(systemName: "pencil")
                        .font(.callout.weight(.bold))
                }
                .buttonStyle(QuietButtonStyle())
                .help("Edit this tab's name and search")
            }
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.checkbox)
        }
        .contentShape(Rectangle())
        .opacity(dragging == tab ? 0.35 : 1)
        .onDrag {
            dragging = tab
            return NSItemProvider(object: tab.rawValue as NSString)
        }
        .onDrop(of: [.text], delegate: TabDropDelegate(target: tab, model: model, dragging: $dragging))
    }
}

/// One tab's identity row — drag grip (optional), identity dot, title, subtitle,
/// and a trailing control. Shared by Settings → Tabs (drag grip + "what the tab is
/// for" subtitle) and Settings → Menu-bar count (no grip + count subtitle), so both
/// lists share the same chrome. Takes resolved display values — never a `PRTab` —
/// because custom tabs' copy lives on the model. Draws a single row; the parent
/// owns the dividers.
struct TabSettingRow<Leading: View, Trailing: View>: View {
    let title: String
    let dotColor: Color
    let subtitle: String
    /// Set for a custom tab's row, whose subtitle is its raw search query —
    /// monospaced so it reads as data, per the app's type conventions.
    var monoSubtitle = false
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    init(title: String,
         dotColor: Color,
         subtitle: String,
         monoSubtitle: Bool = false,
         @ViewBuilder leading: () -> Leading = { EmptyView() },
         @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.dotColor = dotColor
        self.subtitle = subtitle
        self.monoSubtitle = monoSubtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Layout.roomy) {
            leading
            Circle().fill(dotColor).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.appText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(monoSubtitle ? .caption.monospaced() : .caption)
                    .foregroundStyle(.appTextTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: Layout.base)
            trailing
        }
        .tabSettingRowPadding()
    }
}

extension View {
    /// The row inset shared by every row in the Settings tab lists — one
    /// definition so the New Tab row can't drift out of alignment with
    /// `TabSettingRow` above it.
    func tabSettingRowPadding() -> some View {
        padding(.horizontal, Layout.roomy).padding(.vertical, Layout.base + 1)
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
