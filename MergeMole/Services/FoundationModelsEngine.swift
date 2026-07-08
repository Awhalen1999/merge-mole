import Foundation
import FoundationModels

/// On-device verdicts via Apple's Foundation Models — free, private, no API key,
/// no network. If the model isn't available on this Mac (Intel, or Apple
/// Intelligence off), `isAvailable` is false and `AppModel` routes around it so
/// cards fall back cleanly to data-only.
///
/// Uses guided generation: the model returns a `@Generable` value directly, so
/// there's no JSON to parse and no "respond in this format" fragility.
@available(macOS 26, *)
struct FoundationModelsEngine: VerdictEngine {

    /// Maps the framework's availability to the app's OS-agnostic enum. A lightweight
    /// status read — it never loads the model. `Availability` is frozen (available /
    /// unavailable), but `UnavailableReason` is not, so the inner switch keeps an
    /// `@unknown default` for reasons a future OS might add.
    static var availability: OnDeviceAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled: return .appleIntelligenceOff
            case .modelNotReady:               return .downloading
            case .deviceNotEligible:           return .deviceNotEligible
            @unknown default:                  return .unavailable
            }
        }
    }

    func verdict(for pr: PullRequest) async throws -> Verdict {
        let input = VerdictInput(pr)
        let session = LanguageModelSession { VerdictGuidance.systemPrompt }
        let response = try await session.respond(
            to: input.promptText,
            generating: GeneratedVerdict.self
        )
        // The deterministic floor can only raise the model's call, never lower it.
        return response.content.toVerdict.raisingPriority(toAtLeast: input.priorityFloor)
    }

    /// On-device asks for one at a time: the Neural Engine runs inference serially
    /// anyway, so firing several at once wins no speed — it just spikes CPU, heat,
    /// and battery. One keeps the menu-bar app feather-light on modest Macs.
    var maxConcurrency: Int { 1 }

    /// Warm the shared system model into memory before the first real verdict, so
    /// opening the panel doesn't stall on a cold load. Cheap and idempotent; the OS
    /// evicts the model under memory pressure, so this never pins RAM behind a
    /// closed panel.
    func prewarm() {
        LanguageModelSession { VerdictGuidance.systemPrompt }.prewarm()
    }
}

// MARK: - Guided-generation type (maps to the domain Verdict)

@available(macOS 26, *)
@Generable
private struct GeneratedVerdict {
    @Guide(description: "How urgently the reviewer should look. Most PRs are normal; reserve high/urgent for clear signals. Never go below any stated priority floor.")
    let priority: GeneratedPriority
    @Guide(description: "What the PR does, in one present-tense line of at most 14 words. Start with a verb, no \"This PR\" preamble, no trailing period, no em dashes, and don't just repeat the title.")
    let summary: String
    @Guide(description: "One short sentence, at most 25 words, naming the single biggest thing to watch or where to look first. A quick peek, not a full analysis. Don't enumerate risks or restate the summary. No em dashes, no trailing period.")
    let rationale: String

    var toVerdict: Verdict {
        Verdict(priority: priority.value, summary: summary, rationale: rationale)
    }
}

@available(macOS 26, *)
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
