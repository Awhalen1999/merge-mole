import Foundation

/// Produces a `Verdict` for a PR. This is the seam behind all three AI modes:
/// Step 5 adds a `FoundationModelsEngine` (on-device) and a `RemoteModelEngine`
/// (bring-your-own key / Ollama) that both conform here. "AI off" isn't an
/// engine at all — AppModel simply holds none and marks verdicts `.off`.
protocol VerdictEngine: Sendable {
    func verdict(for pr: PullRequest) async throws -> Verdict
}

/// Canned verdicts with a small delay, so the loading → ready transition is
/// real during development. Replaced by the actual model engines at Step 5.
struct SampleVerdictEngine: VerdictEngine {
    var latency: Duration = .milliseconds(700)

    func verdict(for pr: PullRequest) async throws -> Verdict {
        try await Task.sleep(for: latency)
        return SampleData.verdict(for: pr)
    }
}
