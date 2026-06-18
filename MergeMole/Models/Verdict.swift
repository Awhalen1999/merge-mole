import Foundation

/// The AI's read on a single PR.
///
/// The shape is identical regardless of backend — on-device Foundation Models,
/// a bring-your-own hosted model, or local Ollama all produce a `Verdict`. The
/// card never knows (or cares) which one did.
struct Verdict: Hashable, Sendable {
    var effort: EffortTier
    var priority: Priority
    /// One-line, plain-language summary of what the PR *is*.
    var summary: String
    /// One clause of *why* the verdict landed where it did. Every verdict is
    /// auditable — never a black box (PLAN.md, guiding principles).
    var rationale: String
}

/// How much work reviewing/understanding this PR will actually take — the AI's
/// judgement, shown alongside the native `SizeBucket`, not derived from it.
enum EffortTier: Int, CaseIterable, Sendable, Comparable {
    case trivial
    case easy
    case moderate
    case involved
    case heavy

    var label: String {
        switch self {
        case .trivial:  return "Trivial"
        case .easy:     return "Easy"
        case .moderate: return "Moderate"
        case .involved: return "Involved"
        case .heavy:    return "Heavy"
        }
    }

    static func < (lhs: EffortTier, rhs: EffortTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// What to look at first. Drives ordering and (later) the menu-bar badge.
enum Priority: Int, CaseIterable, Sendable, Comparable {
    case low
    case normal
    case high
    case urgent

    var label: String {
        switch self {
        case .low:    return "Low"
        case .normal: return "Normal"
        case .high:   return "High"
        case .urgent: return "Urgent"
        }
    }

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The single value the card branches on.
///
/// This is the heart of the "seamless across all three AI modes" requirement:
/// the card reads *one* value and switches on it, rather than carrying three
/// layouts. AI off → `.off` (the AI rows simply don't exist). AI on but still
/// thinking → `.loading` (a subtle placeholder, never a blank gap).
enum VerdictState: Sendable {
    case off                  // AI disabled — card collapses to data-only
    case loading              // AI on, verdict still computing
    case ready(Verdict)
    case failed(String)       // couldn't analyze; reason for the (quiet) note
}
