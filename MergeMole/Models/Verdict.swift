import Foundation

/// The AI's read on a single PR.
///
/// The shape is identical regardless of backend — on-device Foundation Models,
/// a bring-your-own hosted model, or local Ollama all produce a `Verdict`. The
/// card never knows (or cares) which one did.
struct Verdict: Codable, Hashable, Sendable {
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
enum EffortTier: Int, CaseIterable, Sendable, Comparable, Codable {
    case skim
    case quick
    case moderate
    case deep
    case heavy

    var label: String {
        switch self {
        case .skim:     return "Skim"
        case .quick:    return "Quick"
        case .moderate: return "Moderate"
        case .deep:     return "Deep"
        case .heavy:    return "Heavy"
        }
    }

    /// The lowercase token a model emits / we parse. One source of truth for the
    /// BYO prompt's allowed values *and* its parser, so they can never drift.
    var wireName: String {
        switch self {
        case .skim:     return "skim"
        case .quick:    return "quick"
        case .moderate: return "moderate"
        case .deep:     return "deep"
        case .heavy:    return "heavy"
        }
    }

    /// Lenient parse from a model's reply; anything unrecognized falls to the
    /// middle tier rather than failing the whole verdict.
    init(wire raw: String?) {
        self = EffortTier.allCases.first { $0.wireName == raw?.lowercased() } ?? .moderate
    }

    /// `"trivial|easy|moderate|involved|heavy"` — drop straight into a prompt.
    static var wireList: String { allCases.map(\.wireName).joined(separator: "|") }

    static func < (lhs: EffortTier, rhs: EffortTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// What to look at first. Drives ordering and (later) the menu-bar badge.
enum Priority: Int, CaseIterable, Sendable, Comparable, Codable {
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

    /// The lowercase token a model emits / we parse (see `EffortTier.wireName`).
    var wireName: String {
        switch self {
        case .low:    return "low"
        case .normal: return "normal"
        case .high:   return "high"
        case .urgent: return "urgent"
        }
    }

    /// Lenient parse; unrecognized values fall back to `.normal`.
    init(wire raw: String?) {
        self = Priority.allCases.first { $0.wireName == raw?.lowercased() } ?? .normal
    }

    /// `"low|normal|high|urgent"` — drop straight into a prompt.
    static var wireList: String { allCases.map(\.wireName).joined(separator: "|") }

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
