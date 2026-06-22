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

    /// True once the AI has a verdict — its effort tier then stands in for the
    /// size bucket, so the card doesn't show both.
    private var showsEffort: Bool {
        if case .ready = verdict { return true }
        return false
    }

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
        HStack(alignment: .top, spacing: Layout.snug) {
            Avatar(url: pr.authorAvatarURL)
                .help(pr.author)
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
            // Repo · comments ···· last-updated
            HStack(spacing: Layout.snug) {
                Text("\(pr.repository) #\(pr.number)")
                if pr.commentCount > 0 {
                    Label("\(pr.commentCount)", systemImage: "text.bubble")
                        .labelStyle(.titleAndIcon)
                        .monospacedDigit()
                }
                Spacer(minLength: Layout.tight)
                Text(pr.updatedAt.relativeShort)
            }
            .font(.caption)
            .foregroundStyle(.appTextTertiary)

            // Branch ···· pending reviewers · age-since-opened
            HStack(spacing: Layout.snug) {
                Label("\(pr.headBranch) → \(pr.baseBranch)", systemImage: "arrow.triangle.branch")
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                Spacer(minLength: Layout.tight)
                if !pr.requestedReviewers.isEmpty {
                    ReviewerAvatars(reviewers: pr.requestedReviewers)
                }
                Text("opened \(pr.createdAt.relativeShort)")
                    .fixedSize()
            }
            .font(.caption2)
            .foregroundStyle(.appTextSecondary)

            // Stats + status — wraps as it fills.
            FlowLayout {
                // The AI effort tier subsumes the size bucket, so we only show the
                // raw size pill when there's no effort badge (AI off/loading/failed).
                // The +/− line counts stay either way — that's the raw size signal.
                if !showsEffort { SizeBadge(bucket: pr.sizeBucket) }
                // GitHub-style diffstat: additions green, deletions red.
                (Text("+\(pr.additions)").foregroundStyle(Color.appGreen)
                 + Text(" −\(pr.deletions)").foregroundStyle(Color.appRed))
                    .font(.caption2.monospacedDigit())
                if pr.commitCount > 0 {
                    Text("\(pr.commitCount) commits")
                        .font(.caption2)
                        .foregroundStyle(.appTextTertiary)
                }
                if pr.reviewState != .approved { ApprovalsBadge(count: pr.approvals) }
                ReviewBadge(state: pr.reviewState)
                ChecksBadge(state: pr.checksState)
                ConflictBadge(state: pr.mergeable)
                BehindBadge(isBehind: pr.isBehindBase)
                ConversationsBadge(resolved: pr.resolvedThreads, unresolved: pr.unresolvedThreads)
                FirstTimerBadge(isFirstTime: pr.isFirstTimeContributor)
                ForkBadge(isFromFork: pr.isFromFork)
            }

            // Labels — their own wrapping row, only when present.
            if !pr.labels.isEmpty {
                FlowLayout {
                    ForEach(pr.labels, id: \.self) { LabelPill(text: $0) }
                }
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
