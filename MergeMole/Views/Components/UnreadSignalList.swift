import SwiftUI

/// The activity-signal checkboxes: which kinds of PR activity re-flag a read PR.
/// One list shared by Settings → Unread and the onboarding unread step, so the
/// two surfaces can't drift. Full-bleed: rows carry their own insets and the
/// hairlines run edge to edge; hosts provide the surrounding card.
struct UnreadSignalList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            UnreadSignalRow(signal: .commits, isOn: binding(.commits))
            UnreadSignalRow(signal: .baseBranchMerges, isOn: binding(.baseBranchMerges), indented: true)
                .disabled(!model.unreadSignals.contains(.commits))
            Hairline()
            UnreadSignalRow(signal: .prose, isOn: binding(.prose))
            Hairline()
            UnreadSignalRow(signal: .review, isOn: binding(.review))
            Hairline()
            UnreadSignalRow(signal: .status, isOn: binding(.status))
            Hairline()
            UnreadSignalRow(signal: .labels, isOn: binding(.labels))
            Hairline()
            UnreadSignalRow(signal: .comments, isOn: binding(.comments))
        }
    }

    /// A checkbox for one unread signal, writing through to the model's set.
    private func binding(_ signal: UnreadSignal) -> Binding<Bool> {
        Binding(
            get: { model.unreadSignals.contains(signal) },
            set: { on in
                if on { model.unreadSignals.insert(signal) }
                else { model.unreadSignals.remove(signal) }
            }
        )
    }
}

/// One checkbox row. The base-branch case renders indented beneath "New commits
/// are pushed" — it refines that signal (which head moves count) rather than
/// standing alone, and disables with it.
private struct UnreadSignalRow: View {
    let signal: UnreadSignal
    @Binding var isOn: Bool
    var indented = false

    var body: some View {
        Toggle(signal.label, isOn: $isOn)
            .toggleStyle(.checkbox)
            .tint(.appAccent)
            .padding(.leading, Layout.roomy + (indented ? Layout.generous : 0))
            .padding(.trailing, Layout.roomy)
            .padding(.vertical, Layout.base)
    }
}
