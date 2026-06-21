import Foundation
import FoundationModels

/// On-device verdicts via Apple's Foundation Models — free, private, no API key,
/// no network. If the model isn't available on this Mac (Intel, or Apple
/// Intelligence off), `isAvailable` is false and `AppModel` routes around it so
/// cards fall back cleanly to data-only.
///
/// Uses guided generation: the model returns a `@Generable` value directly, so
/// there's no JSON to parse and no "respond in this format" fragility.
struct FoundationModelsEngine: VerdictEngine {

    static var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available:   return true
        case .unavailable: return false
        @unknown default:  return false
        }
    }

    func verdict(for pr: PullRequest) async throws -> Verdict {
        let session = LanguageModelSession { Self.instructions }
        let response = try await session.respond(
            to: Self.prompt(for: pr),
            generating: GeneratedVerdict.self
        )
        return response.content.toVerdict
    }

    private static let instructions = """
    You triage GitHub pull requests for a busy reviewer. From the metadata you are \
    given, judge how much effort reviewing the PR will take, how urgently the \
    reviewer should look at it, summarize what it does in one short sentence, and \
    give one short clause explaining your call. Be concrete, and never invent \
    details that aren't implied by the input.
    """

    private static func prompt(for pr: PullRequest) -> String {
        """
        Title: \(pr.title)
        Repository: \(pr.repository)
        Author: \(pr.author)
        Branch: \(pr.headBranch) -> \(pr.baseBranch)
        Draft: \(pr.isDraft)
        Review state: \(pr.reviewState.rawValue)
        CI: \(pr.checksState.rawValue)
        Changes: +\(pr.additions) / -\(pr.deletions) across \(pr.changedFiles) files (size \(pr.sizeBucket.label))
        """
    }
}

// MARK: - Guided-generation type (maps to the domain Verdict)

@Generable
private struct GeneratedVerdict {
    @Guide(description: "How much effort reviewing this PR will take.")
    let effort: GeneratedEffort
    @Guide(description: "How urgently the reviewer should look at this PR.")
    let priority: GeneratedPriority
    @Guide(description: "One short sentence describing what the PR does.")
    let summary: String
    @Guide(description: "One short clause explaining the effort and priority call.")
    let rationale: String

    var toVerdict: Verdict {
        Verdict(effort: effort.tier, priority: priority.value, summary: summary, rationale: rationale)
    }
}

@Generable
private enum GeneratedEffort {
    case trivial, easy, moderate, involved, heavy

    var tier: EffortTier {
        switch self {
        case .trivial:  return .trivial
        case .easy:     return .easy
        case .moderate: return .moderate
        case .involved: return .involved
        case .heavy:    return .heavy
        }
    }
}

@Generable
private enum GeneratedPriority {
    case low, normal, high, urgent

    var value: Priority {
        switch self {
        case .low:    return .low
        case .normal: return .normal
        case .high:   return .high
        case .urgent: return .urgent
        }
    }
}
