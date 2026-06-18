import SwiftUI

/// A small rounded label. The one primitive every status badge is built from,
/// so spacing and shape stay consistent across the card.
struct Pill: View {
    let text: String
    var systemImage: String?
    var tint: Color = .secondary

    init(_ text: String, systemImage: String? = nil, tint: Color = .secondary) {
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

struct SizeBadge: View {
    let bucket: SizeBucket
    var body: some View { Pill(bucket.label, tint: .secondary) }
}

struct EffortBadge: View {
    let effort: EffortTier
    var body: some View {
        Pill(effort.label, systemImage: "gauge.with.dots.needle.50percent", tint: tint)
    }
    private var tint: Color {
        switch effort {
        case .trivial:  return .green
        case .easy:     return .mint
        case .moderate: return .yellow
        case .involved: return .orange
        case .heavy:    return .red
        }
    }
}

struct PriorityBadge: View {
    let priority: Priority
    var body: some View {
        Pill(priority.label, systemImage: "flag.fill", tint: tint)
    }
    private var tint: Color {
        switch priority {
        case .low:    return .secondary
        case .normal: return .blue
        case .high:   return .orange
        case .urgent: return .red
        }
    }
}

struct ReviewBadge: View {
    let state: PullRequest.ReviewState
    var body: some View {
        switch state {
        case .pending:          Pill("Review pending", systemImage: "clock", tint: .secondary)
        case .changesRequested: Pill("Changes requested", systemImage: "exclamationmark.bubble", tint: .orange)
        case .approved:         Pill("Approved", systemImage: "checkmark.seal", tint: .green)
        }
    }
}

struct ChecksBadge: View {
    let state: PullRequest.ChecksState
    var body: some View {
        switch state {
        case .unknown: EmptyView()
        case .pending: Pill("CI running", systemImage: "circle.dashed", tint: .secondary)
        case .passing: Pill("CI green", systemImage: "checkmark.circle", tint: .green)
        case .failing: Pill("CI failing", systemImage: "xmark.circle", tint: .red)
        }
    }
}
