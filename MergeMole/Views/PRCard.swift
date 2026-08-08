import SwiftUI

/// One PR in the list — a full-width section (the list separates rows with
/// hairlines, so the card itself carries no border or surface). The whole row is
/// a button that opens the PR on GitHub.
///
/// A colored edge bar flags priority. Everything AI-derived flows from the single
/// `verdict` value — the priority chip + edge bar, the summary, and the rationale.
/// AI off → those simply don't render, and the card collapses to clean data-only.
struct PRCard: View {
    let pr: PullRequest
    let verdict: VerdictState

    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var hovering = false

    /// Read/unread is read live from the model so the dot and the context-menu label
    /// always reflect the current state (the card re-renders when read state changes).
    private var isUnread: Bool { model.isUnread(pr) }

    var body: some View {
        Button {
            model.markRead(pr)          // opening a PR counts as reading it
            openURL(pr.url)
        } label: { row }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
            // Rebuilt from live state each time it opens, so the label always matches
            // the PR's current read/unread state.
            .contextMenu {
                if isUnread {
                    Button("Mark as Read") { model.markRead(pr) }
                } else {
                    Button("Mark as Unread") { model.markUnread(pr) }
                }
            }
    }

    private var isCompact: Bool { model.cardLayout == .compact }
    private var isMinimal: Bool { model.cardDetail == .minimal }

    private var row: some View {
        HStack(spacing: 0) {
            // The priority edge bar. Spans the full section height; clear (a bare
            // gutter) for normal/low so only what's urgent draws a colored edge.
            Rectangle()
                .fill(priorityColor ?? .clear)
                .frame(width: Layout.accentBar)
                .frame(maxHeight: .infinity)

            content
                .padding(.vertical, isCompact ? Layout.roomy : Layout.generous)
                // Content text lands on Layout.margin: the gutter eats the rest, so
                // titles align with the header brand and tab labels above.
                .padding(.leading, Layout.margin - Layout.accentBar)
                .padding(.trailing, Layout.margin)
        }
        .background(hovering ? Color.appFillHover : .clear)
        .contentShape(Rectangle())
    }

    /// Two independent axes. Layout (Standard/Compact) keeps the same rows and
    /// tightens them: paddings, type sizes, and the avatar each step down a notch.
    /// Detail (Detailed/Minimal) strips rows instead: Minimal is title, repo
    /// #number, branches, and the verdict — no avatar, size chip, stats, or labels.
    private var content: some View {
        VStack(alignment: .leading, spacing: isCompact ? Layout.snug : Layout.base) {
            badges
            title
            repoLine
            insight       // summary + rationale / loading / failed — gone when AI off
            branchLine
            if !isMinimal {
                stats
                labels    // only when labels exist
            }
        }
    }

    // MARK: Rows

    /// Leading unread dot (when unseen) · priority (only when it wants attention) ·
    /// the size glyph. On Minimal the unread dot moves inline with the title and
    /// the size glyph is cut, so this row only appears for a high/urgent priority
    /// badge — otherwise it vanishes rather than carrying an empty row's spacing.
    @ViewBuilder
    private var badges: some View {
        if !isMinimal || wantsPriorityBadge {
            HStack(spacing: Layout.snug) {
                if isUnread && !isMinimal {
                    UnreadDot()
                }
                if let priority = readyVerdict?.priority, priority >= .high {
                    PriorityBadge(priority: priority)
                }
                if !isMinimal {
                    SizeBadge(bucket: pr.sizeBucket)
                }
            }
        }
    }

    private var wantsPriorityBadge: Bool {
        readyVerdict.map { $0.priority >= .high } ?? false
    }

    /// Minimal swaps the avatar for an inline unread dot and puts the +/− line
    /// counts on the title's trailing edge (they lose their stats row there).
    /// Baseline alignment keeps the dot and the counts on the title's first line
    /// when it wraps.
    private var title: some View {
        HStack(alignment: isMinimal ? .firstTextBaseline : .top, spacing: Layout.base) {
            if !isMinimal {
                Avatar(url: pr.authorAvatarURL, size: isCompact ? 18 : 22)
                    .help(pr.author)
            } else if isUnread {
                UnreadDot()
            }
            Text(pr.title)
                .font(isCompact ? .callout.weight(.semibold) : .headline)
                .foregroundStyle(.appText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if isMinimal {
                lineCounts
            }
        }
    }

    private var lineCounts: some View {
        HStack(spacing: Layout.tight) {
            Text("+\(pr.additions)").foregroundStyle(Color.appGreen)
            Text("−\(pr.deletions)").foregroundStyle(Color.appRed)
        }
        .font(.caption.monospacedDigit())
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
                    .font(isCompact ? .subheadline : .callout)
                    .foregroundStyle(.appText)
                    .fixedSize(horizontal: false, vertical: true)
                if !isMinimal {
                    HStack(alignment: .firstTextBaseline, spacing: Layout.tight) {
                        Image(systemName: "sparkles")
                        Text(v.rationale)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.caption)
                    .foregroundStyle(.appTextSecondary)
                }
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

    /// Metrics then status, wrapping as the row fills. The +/− line counts are the
    /// always-on size signal — they stay regardless of AI.
    private var stats: some View {
        FlowLayout(spacing: Layout.base) {
            lineCounts

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

/// The 7pt accent dot marking an unseen PR — one shape whether it leads the badge
/// row (Detailed) or sits inline before the title (Minimal).
private struct UnreadDot: View {
    var body: some View {
        Circle().fill(Color.appAccent).frame(width: 7, height: 7)
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
    .environment(AppModel(secrets: InMemorySecretStore()))
}
