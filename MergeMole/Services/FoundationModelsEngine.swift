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
            to: VerdictInput(pr).promptText,
            generating: GeneratedVerdict.self
        )
        return response.content.toVerdict
    }

    private static let instructions = """
    You triage GitHub pull requests for a busy reviewer who wants, at a glance, to \
    know what each PR is and whether to look now. From the metadata and description, \
    judge the review effort and the priority, then write a one-line summary and one \
    clause of why. Be specific and concrete; never invent details the input doesn't \
    support. If the description is thin, judge from the title, size, and file count.
    """
}

// MARK: - Guided-generation type (maps to the domain Verdict)

@Generable
private struct GeneratedVerdict {
    @Guide(description: "How much focused effort reviewing this PR will take.")
    let effort: GeneratedEffort
    @Guide(description: "How urgently the reviewer should look, given review state, CI, size, and risk.")
    let priority: GeneratedPriority
    @Guide(description: "What the PR actually does, in one concrete line of at most 14 words. Start with a verb, no \"This PR\" preamble, and don't just repeat the title.")
    let summary: String
    @Guide(description: "The single most decision-relevant reason for the effort and priority call, as one short clause.")
    let rationale: String

    var toVerdict: Verdict {
        Verdict(effort: effort.tier, priority: priority.value, summary: summary, rationale: rationale)
    }
}

@Generable
private enum GeneratedEffort {
    case skim, quick, moderate, deep, heavy

    var tier: EffortTier {
        switch self {
        case .skim:     return .skim
        case .quick:    return .quick
        case .moderate: return .moderate
        case .deep:     return .deep
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
