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

/// Review-conversation resolution at a glance: open threads in amber (the
/// actionable count), resolved in muted green — or all-green when nothing's left
/// open. Silent when a PR has no review threads at all.
struct ConversationsBadge: View {
    let resolved: Int
    let unresolved: Int

    var body: some View {
        let total = resolved + unresolved
        if total > 0 {
            HStack(spacing: Layout.snug) {
                if unresolved > 0 {
                    segment("\(unresolved)", systemImage: "bubble.left.fill", tint: .appAmber)
                }
                if resolved > 0 {
                    segment("\(resolved)", systemImage: "checkmark.bubble.fill",
                            tint: unresolved == 0 ? .appGreen : .appTextSecondary)
                }
            }
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.appText.opacity(0.06), in: Capsule())
            .help("\(unresolved) unresolved · \(resolved) resolved conversation\(total == 1 ? "" : "s")")
        }
    }

    private func segment(_ text: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
            Text(text).monospacedDigit()
        }
        .foregroundStyle(tint)
    }
}
