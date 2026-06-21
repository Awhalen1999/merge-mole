import SwiftUI

/// One PR in the list. The whole card is a button that opens the PR on GitHub.
///
/// Top half is always-present data (title, repo, age, branch, size, review/CI).
/// The bottom half is the AI section, driven entirely by the single `verdict`
/// value — the card branches on it once and never carries per-mode layouts.
struct PRCard: View {
    let pr: PullRequest
    let verdict: VerdictState

    @Environment(\.openURL) private var openURL
    @State private var hovering = false

    var body: some View {
        Button { openURL(pr.url) } label: { card }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Layout.base) {
            header
            metadata
            aiSection   // collapses to nothing when AI is off
        }
        .padding(Layout.roomy)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: Layout.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardRadius)
                .strokeBorder(hovering ? Color.appAccent.opacity(0.45) : .appHairline, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: Layout.cardRadius))
    }

    // MARK: Always-present data

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Layout.tight) {
            Text(pr.title)
                .font(.headline)
                .foregroundStyle(.appText)
                .lineLimit(2)
            Spacer(minLength: Layout.tight)
            if pr.isDraft {
                Pill("Draft", tint: .appTextTertiary)
            }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: Layout.tight) {
            HStack(spacing: Layout.tight) {
                Text("\(pr.repository) #\(pr.number)")
                Spacer(minLength: Layout.tight)
                Text(pr.updatedAt.relativeShort)
            }
            .font(.caption)
            .foregroundStyle(.appTextTertiary)

            Label("\(pr.headBranch) → \(pr.baseBranch)", systemImage: "arrow.triangle.branch")
                .labelStyle(.titleAndIcon)
                .font(.caption2)
                .foregroundStyle(.appTextSecondary)
                .lineLimit(1)

            HStack(spacing: Layout.snug) {
                SizeBadge(bucket: pr.sizeBucket)
                Text("+\(pr.additions) −\(pr.deletions)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.appTextSecondary)
                ReviewBadge(state: pr.reviewState)
                ChecksBadge(state: pr.checksState)
            }
        }
    }

    // MARK: AI section — the single branch on VerdictState

    @ViewBuilder
    private var aiSection: some View {
        switch verdict {
        case .off:
            EmptyView()   // data-only card; looks as if the AI section never existed

        case .loading:
            HStack(spacing: Layout.snug) {
                ProgressView().controlSize(.small)
                Text("Analyzing…")
                    .font(.caption)
                    .foregroundStyle(.appTextSecondary)
            }

        case .ready(let v):
            Hairline().padding(.vertical, Layout.hair)
            VStack(alignment: .leading, spacing: Layout.tight) {
                HStack(spacing: Layout.snug) {
                    EffortBadge(effort: v.effort)
                    // Priority shows a color only when it wants attention.
                    if v.priority >= .high { PriorityBadge(priority: v.priority) }
                }
                Text(v.summary)
                    .font(.caption)
                    .foregroundStyle(.appText)
                Label(v.rationale, systemImage: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.appTextSecondary)
            }

        case .failed(let reason):
            Label(reason, systemImage: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundStyle(.appTextSecondary)
        }
    }
}

#Preview("Card states") {
    let pr = SampleData.pullRequests[0]
    return VStack(spacing: Layout.roomy) {
        PRCard(pr: pr, verdict: .ready(SampleData.verdict(for: pr)))
        PRCard(pr: SampleData.pullRequests[1], verdict: .loading)
        PRCard(pr: SampleData.pullRequests[2], verdict: .off)
    }
    .padding()
    .frame(width: 360)
    .background(Color.appBackground)
}
