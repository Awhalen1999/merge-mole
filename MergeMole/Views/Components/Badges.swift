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

/// A small rounded label. The one primitive every status badge is built from,
/// so spacing and shape stay consistent across the card.
struct Pill: View {
    let text: String
    var systemImage: String?
    var tint: Color

    init(_ text: String, systemImage: String? = nil, tint: Color = .appTextSecondary) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(tint)
        .background(tint.opacity(0.14), in: Capsule())
    }
}

/// Native, AI-free size — always neutral; it's reference data, not a signal.
struct SizeBadge: View {
    let bucket: SizeBucket
    var body: some View { Pill(bucket.label, tint: .appTextSecondary) }
}

/// The signature feature: AI effort. Intensity reads from the gauge needle, not
/// a hue — keeping it clear of the red/amber/green status spectrum. Carries a
/// touch more weight (primary ink) than the neutral badges around it.
struct EffortBadge: View {
    let effort: EffortTier
    var body: some View { Pill(effort.label, systemImage: gauge, tint: .appText) }

    private var gauge: String {
        switch effort {
        case .skim:     return "gauge.with.dots.needle.0percent"
        case .quick:    return "gauge.with.dots.needle.33percent"
        case .moderate: return "gauge.with.dots.needle.50percent"
        case .deep:     return "gauge.with.dots.needle.67percent"
        case .heavy:    return "gauge.with.dots.needle.100percent"
        }
    }
}

/// Priority colors only when it wants attention — high/urgent. Low/normal stay
/// quiet (the list is already priority-sorted). Never blue: that's the accent.
struct PriorityBadge: View {
    let priority: Priority
    var body: some View {
        Pill(priority.label, systemImage: "flag.fill", tint: tint)
    }
    private var tint: Color {
        switch priority {
        case .low:    return .appTextTertiary
        case .normal: return .appTextSecondary
        case .high:   return .appAmber
        case .urgent: return .appRed
        }
    }
}

struct ReviewBadge: View {
    let state: PullRequest.ReviewState
    var body: some View {
        switch state {
        case .pending:          Pill("Review pending", systemImage: "clock", tint: .appTextSecondary)
        case .changesRequested: Pill("Changes requested", systemImage: "exclamationmark.bubble", tint: .appAmber)
        case .approved:         Pill("Approved", systemImage: "checkmark.seal", tint: .appGreen)
        }
    }
}

struct ChecksBadge: View {
    let state: PullRequest.ChecksState
    var body: some View {
        switch state {
        case .unknown: EmptyView()
        case .pending: Pill("CI running", systemImage: "circle.dashed", tint: .appTextSecondary)
        case .passing: Pill("CI green", systemImage: "checkmark.circle", tint: .appGreen)
        case .failing: Pill("CI failing", systemImage: "xmark.circle", tint: .appRed)
        }
    }
}

/// Only speaks up when GitHub says the branches conflict. A clean or not-yet-
/// computed merge isn't worth a pill. Amber, not red — it's "needs a rebase"
/// (author action), the same weight as changes-requested; red stays for failing CI.
struct ConflictBadge: View {
    let state: PullRequest.MergeState
    var body: some View {
        if state == .conflicting {
            Pill("Conflicts", systemImage: "exclamationmark.triangle", tint: .appAmber)
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
            Pill("\(count) approved", systemImage: "checkmark.circle.fill", tint: .appGreen)
                .help("\(count) approval\(count == 1 ? "" : "s") so far")
        }
    }
}

/// Head branch trails base — wants an update/rebase before it can merge. Amber,
/// like Conflicts: author action, not a hard failure. Silent otherwise.
struct BehindBadge: View {
    let isBehind: Bool
    var body: some View {
        if isBehind {
            Pill("Behind base", systemImage: "arrow.down", tint: .appAmber)
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
            Pill("First-timer", systemImage: "hand.wave", tint: .appTextSecondary)
                .help("First-time contributor to this repository")
        }
    }
}

struct ForkBadge: View {
    let isFromFork: Bool
    var body: some View {
        if isFromFork {
            Pill("Fork", systemImage: "arrow.triangle.branch", tint: .appTextTertiary)
                .help("Opened from a fork")
        }
    }
}

/// A repo label. Neutral on purpose — color is reserved for status in this app,
/// so the label's text carries the meaning, not an arbitrary GitHub hue.
struct LabelPill: View {
    let text: String
    var body: some View { Pill(text, tint: .appTextSecondary) }
}

/// The actionable review signal: how many conversations still need addressing.
/// Amber, like the other "needs attention" pills. Silent when nothing's open —
/// a PR with no unresolved threads doesn't need to say anything. The resolved
/// count lives in the tooltip so the progress context is a hover away.
struct ConversationsBadge: View {
    let resolved: Int
    let unresolved: Int

    var body: some View {
        if unresolved > 0 {
            Pill("\(unresolved) unresolved", systemImage: "bubble.left.fill", tint: .appAmber)
                .help("\(unresolved) unresolved of \(resolved + unresolved) review conversations")
        }
    }
}
