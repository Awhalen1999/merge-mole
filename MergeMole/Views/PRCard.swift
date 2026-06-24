import SwiftUI

/// One PR in the list — a full-width section (the list separates rows with
/// hairlines, so the card itself carries no border or surface). The whole row is
/// a button that opens the PR on GitHub.
///
/// A colored edge bar flags priority. Everything AI-derived flows from the single
/// `verdict` value — the priority chip + edge bar, the summary, the rationale, and
/// the effort badge beside the line counts. AI off → those simply don't render,
/// and the card collapses to clean data-only.
struct PRCard: View {
    let pr: PullRequest
    let verdict: VerdictState

    @Environment(\.openURL) private var openURL
    @State private var hovering = false

    var body: some View {
        Button { openURL(pr.url) } label: { row }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
    }

    private var row: some View {
        HStack(spacing: 0) {
            // The priority edge bar. Spans the full section height; clear (a bare
            // gutter) for normal/low so only what's urgent draws a colored edge.
            Rectangle()
                .fill(priorityColor ?? .clear)
                .frame(width: Layout.accentBar)
                .frame(maxHeight: .infinity)

            content
                .padding(.vertical, Layout.generous)
                // Content text lands on Layout.margin: the gutter eats the rest, so
                // titles align with the header brand and tab labels above.
                .padding(.leading, Layout.margin - Layout.accentBar)
                .padding(.trailing, Layout.margin)
        }
        .background(hovering ? Color.appText.opacity(0.04) : .clear)
        .contentShape(Rectangle())
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Layout.base) {
            badges
            title
            repoLine
            insight       // summary + rationale / loading / failed — gone when AI off
            branchLine
            stats
            labels        // only when labels exist
        }
    }

    // MARK: Rows

    /// Priority (only when it wants attention) + the always-on size glyph.
    private var badges: some View {
        HStack(spacing: Layout.snug) {
            if let priority = readyVerdict?.priority, priority >= .high {
                PriorityBadge(priority: priority)
            }
            SizeBadge(bucket: pr.sizeBucket)
        }
    }

    private var title: some View {
        HStack(alignment: .top, spacing: Layout.base) {
            Avatar(url: pr.authorAvatarURL)
                .help(pr.author)
            Text(pr.title)
                .font(.headline)
                .foregroundStyle(.appText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var repoLine: some View {
        HStack(spacing: Layout.snug) {
            Text("\(pr.repository) #\(pr.number)")
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Layout.tight)
            Text(pr.updatedAt.relativeShort)
                .fixedSize()
        }
        .font(.caption)
        .foregroundStyle(.appTextTertiary)
    }

    /// The single branch on `VerdictState`. Plain-language summary as the lead
    /// line; the one-clause rationale below it, marked with a sparkle.
    @ViewBuilder
    private var insight: some View {
        switch verdict {
        case .off:
            EmptyView()   // data-only card; looks as if the AI section never existed

        case .loading:
            HStack(spacing: Layout.snug) {
                ProgressView().controlSize(.small)
                Text("Analyzing…")
                    .font(.callout)
                    .foregroundStyle(.appTextSecondary)
            }

        case .ready(let v):
            VStack(alignment: .leading, spacing: Layout.tight) {
                Text(v.summary)
                    .font(.callout)
                    .foregroundStyle(.appText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .firstTextBaseline, spacing: Layout.tight) {
                    Image(systemName: "sparkles")
                    Text(v.rationale)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
                .foregroundStyle(.appTextSecondary)
            }

        case .failed(let reason):
            Label(reason, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.appTextSecondary)
        }
    }

    private var branchLine: some View {
        HStack(spacing: Layout.snug) {
            Label("\(pr.headBranch) → \(pr.baseBranch)", systemImage: "arrow.triangle.branch")
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Layout.tight)
            Text("opened \(pr.createdAt.relativeShort)")
                .fixedSize()
        }
        .font(.caption)
        .foregroundStyle(.appTextSecondary)
    }

    /// Metrics then status, wrapping as the row fills. Effort leads — beside the
    /// raw +/− counts, never instead of them. The +/− line counts stay regardless
    /// of AI; that's the always-on size signal.
    private var stats: some View {
        FlowLayout(spacing: Layout.base) {
            if case .ready(let v) = verdict { EffortBadge(effort: v.effort) }

            (Text("+\(pr.additions)").foregroundStyle(Color.appGreen)
             + Text(" −\(pr.deletions)").foregroundStyle(Color.appRed))
                .font(.caption.monospacedDigit())

            if pr.commitCount > 0 {
                Text("\(pr.commitCount) commits")
                    .font(.caption)
                    .foregroundStyle(.appTextTertiary)
            }
            if pr.commentCount > 0 {
                Label("\(pr.commentCount)", systemImage: "text.bubble")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.appTextTertiary)
            }

            if pr.reviewState != .approved { ApprovalsBadge(count: pr.approvals) }
            ReviewBadge(state: pr.reviewState)
            ChecksBadge(state: pr.checksState)
            ConflictBadge(state: pr.mergeable)
            BehindBadge(isBehind: pr.isBehindBase)
            ConversationsBadge(resolved: pr.resolvedThreads, unresolved: pr.unresolvedThreads)
            if pr.isDraft { DraftBadge() }
            FirstTimerBadge(isFirstTime: pr.isFirstTimeContributor)
            ForkBadge(isFromFork: pr.isFromFork)
        }
    }

    @ViewBuilder
    private var labels: some View {
        if !pr.labels.isEmpty {
            FlowLayout {
                ForEach(pr.labels, id: \.self) { LabelPill(text: $0) }
            }
        }
    }

    // MARK: Verdict-derived

    private var readyVerdict: Verdict? {
        if case .ready(let v) = verdict { return v }
        return nil
    }

    /// The edge-bar color: only high/urgent get one; everything else is a bare
    /// gutter. Mirrors `PriorityBadge` — color reserved for what wants attention.
    private var priorityColor: Color? {
        switch readyVerdict?.priority {
        case .urgent: return .appRed
        case .high:   return .appAmber
        default:      return nil
        }
    }
}

#Preview("Card states") {
    let pr = SampleData.pullRequests[0]
    return VStack(spacing: 0) {
        PRCard(pr: pr, verdict: .ready(SampleData.verdict(for: pr)))
        Hairline()
        PRCard(pr: SampleData.pullRequests[1], verdict: .loading)
        Hairline()
        PRCard(pr: SampleData.pullRequests[2], verdict: .off)
    }
    .frame(width: 400)
    .background(Color.appBackground)
}
