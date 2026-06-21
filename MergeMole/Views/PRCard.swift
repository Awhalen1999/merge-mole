import SwiftUI

/// One PR in the list. Top half is always-present data (title, repo, branch,
/// native size, review/CI state). The bottom half is the AI section, driven
/// entirely by the single `verdict` value — the card branches on it once and
/// never carries separate layouts per AI mode.
struct PRCard: View {
    let pr: PullRequest
    let verdict: VerdictState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            metadata
            aiSection   // collapses to nothing when AI is off
        }
        .padding(12)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.appHairline, lineWidth: 1)
        )
    }

    // MARK: Always-present data

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(pr.title)
                .font(.headline)
                .foregroundStyle(.appText)
                .lineLimit(2)
            Spacer(minLength: 4)
            if pr.isDraft {
                Pill("Draft", tint: .appTextTertiary)
            }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(pr.repository) #\(pr.number)")
                .font(.caption)
                .foregroundStyle(.appTextSecondary)

            Label("\(pr.headBranch) → \(pr.baseBranch)", systemImage: "arrow.triangle.branch")
                .labelStyle(.titleAndIcon)
                .font(.caption2)
                .foregroundStyle(.appTextSecondary)
                .lineLimit(1)

            HStack(spacing: 6) {
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
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Analyzing…")
                    .font(.caption)
                    .foregroundStyle(.appTextSecondary)
            }
            .padding(.top, 2)

        case .ready(let v):
            Hairline().padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    EffortBadge(effort: v.effort)
                    PriorityBadge(priority: v.priority)
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
    return VStack(spacing: 10) {
        PRCard(pr: pr, verdict: .ready(SampleData.verdict(for: pr)))
        PRCard(pr: SampleData.pullRequests[1], verdict: .loading)
        PRCard(pr: SampleData.pullRequests[2], verdict: .off)
    }
    .padding()
    .frame(width: 360)
    .background(Color.appBackground)
}
