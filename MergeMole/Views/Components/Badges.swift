import SwiftUI

/// A 1px theme-aware divider. Replaces the default `Divider()` so separators use
/// the Flexoki hairline tone instead of the system gray.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.appHairline)
            .frame(height: 1)
    }
}

/// A small rounded chip. Two fills: a quiet *tint* (default) for neutral chips
/// like labels and a soft-amber priority, or a *solid* fill for a priority that
/// needs to shout. The one primitive the chips are built from, so shape and
/// spacing stay consistent across the card.
struct Pill: View {
    let text: String
    var systemImage: String?
    var tint: Color
    var filled: Bool

    init(_ text: String, systemImage: String? = nil, tint: Color = .appTextSecondary, filled: Bool = false) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
        self.filled = filled
    }

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption2.weight(filled ? .semibold : .medium))
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .foregroundStyle(filled ? Color.white : tint)
        .background(filled ? tint : tint.opacity(0.14), in: Capsule())
    }
}

/// An inline status: a small leading marker — a filled dot, a hollow ring, or an
/// SF Symbol — plus a short tinted label. Replaces the old status *pills*; the
/// redesign reads as a quiet status line rather than a row of chips.
struct StatusItem: View {
    enum Marker { case dot, ring, symbol(String) }
    let marker: Marker
    let text: String
    var tint: Color = .appTextSecondary

    var body: some View {
        HStack(spacing: Layout.tight) {
            marquee
            Text(text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(tint)
    }

    @ViewBuilder private var marquee: some View {
        switch marker {
        case .dot:
            Circle().fill(tint).frame(width: 6, height: 6)
        case .ring:
            Circle().strokeBorder(tint, lineWidth: 1.2).frame(width: 7, height: 7)
        case .symbol(let name):
            Image(systemName: name).font(.caption2.weight(.bold))
        }
    }
}

/// Five ascending bars whose first `filled` are inked — a compact magnitude glyph
/// for PR size. The rest sit at a faint tint so the scale always reads as "of 5".
struct SizeBars: View {
    let filled: Int
    private let heights: [CGFloat] = [4, 6, 8, 10, 12]

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 0.75)
                    .fill(i < filled ? Color.appText : Color.appText.opacity(0.22))
                    .frame(width: 2.5, height: heights[i])
            }
        }
    }
}

/// Native, AI-free size — a quiet neutral chip pairing the bar glyph with a
/// spelled-out label. Always present; it's reference data, not a signal.
struct SizeBadge: View {
    let bucket: SizeBucket
    var body: some View {
        HStack(spacing: 5) {
            SizeBars(filled: bucket.barCount)
            Text(bucket.longLabel)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.appTextSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.appText.opacity(0.06), in: Capsule())
    }
}

/// Priority shouts only when it wants attention — high/urgent. Urgent is a solid
/// red chip; high a softer amber tint. Low/normal don't render (the list is
/// already priority-sorted). Never blue: that's the accent.
struct PriorityBadge: View {
    let priority: Priority
    var body: some View {
        Pill(priority.label,
             tint: priority == .urgent ? .appRed : .appAmber,
             filled: priority == .urgent)
    }
}

struct ReviewBadge: View {
    let state: PullRequest.ReviewState
    var body: some View {
        switch state {
        case .pending:          StatusItem(marker: .ring, text: "Review pending", tint: .appTextTertiary)
        case .changesRequested: StatusItem(marker: .symbol("xmark"), text: "Changes requested", tint: .appRed)
        case .approved:         StatusItem(marker: .dot, text: "Approved", tint: .appGreen)
        }
    }
}

struct ChecksBadge: View {
    let state: PullRequest.ChecksState
    var body: some View {
        switch state {
        case .unknown: EmptyView()
        case .pending: StatusItem(marker: .dot, text: "Checks running", tint: .appAmber)
        case .passing: StatusItem(marker: .dot, text: "Checks passing", tint: .appGreen)
        case .failing: StatusItem(marker: .dot, text: "Checks failing", tint: .appRed)
        }
    }
}

/// Only speaks up when GitHub says the branches conflict. A clean or not-yet-
/// computed merge isn't worth a line. Red — it's a hard blocker to merging,
/// same weight as failing CI.
struct ConflictBadge: View {
    let state: PullRequest.MergeState
    var body: some View {
        if state == .conflicting {
            StatusItem(marker: .dot, text: "Merge conflict", tint: .appRed)
        }
    }
}

/// How many approvals so far — green, a sense of how close to merge. Hidden at
/// zero. Shown only while not yet fully approved, so it reads as progress rather
/// than echoing the "Approved" review badge.
struct ApprovalsBadge: View {
    let count: Int
    var body: some View {
        if count > 0 {
            StatusItem(marker: .dot, text: "\(count) approved", tint: .appGreen)
                .help("\(count) approval\(count == 1 ? "" : "s") so far")
        }
    }
}

/// Head branch trails base — wants an update/rebase before it can merge. Amber:
/// author action, not a hard failure. Silent otherwise.
struct BehindBadge: View {
    let isBehind: Bool
    var body: some View {
        if isBehind {
            StatusItem(marker: .symbol("arrow.down"), text: "Behind base", tint: .appAmber)
                .help("This branch is behind its base — needs an update or rebase")
        }
    }
}

/// Quiet nudges that a PR deserves a closer look: a first-time contributor or a
/// PR from a fork. Neutral, not status — they inform, they don't alarm.
struct FirstTimerBadge: View {
    let isFirstTime: Bool
    var body: some View {
        if isFirstTime {
            StatusItem(marker: .symbol("hand.wave"), text: "First-timer", tint: .appTextTertiary)
                .help("First-time contributor to this repository")
        }
    }
}

struct ForkBadge: View {
    let isFromFork: Bool
    var body: some View {
        if isFromFork {
            StatusItem(marker: .symbol("arrow.triangle.branch"), text: "Fork", tint: .appTextTertiary)
                .help("Opened from a fork")
        }
    }
}

/// A work-in-progress PR. Quiet hollow ring, neutral — it's a state, not a problem.
struct DraftBadge: View {
    var body: some View {
        StatusItem(marker: .ring, text: "Draft", tint: .appTextTertiary)
    }
}

/// A repo label. Neutral on purpose — color is reserved for status in this app,
/// so the label's text carries the meaning, not an arbitrary GitHub hue.
struct LabelPill: View {
    let text: String
    var body: some View { Pill(text, tint: .appTextSecondary) }
}

/// The actionable review signal: how many conversations still need addressing.
/// A hollow amber ring, like the other "needs attention" cues. Silent when
/// nothing's open. The resolved count lives in the tooltip, a hover away.
struct ConversationsBadge: View {
    let resolved: Int
    let unresolved: Int

    var body: some View {
        if unresolved > 0 {
            StatusItem(marker: .ring, text: "\(unresolved) unresolved", tint: .appAmber)
                .help("\(unresolved) unresolved of \(resolved + unresolved) review conversations")
        }
    }
}
