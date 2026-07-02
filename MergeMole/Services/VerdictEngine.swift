import Foundation

/// Produces a `Verdict` for a PR. This is the seam behind all three AI modes:
/// `FoundationModelsEngine` (on-device) and `RemoteVerdictEngine` (bring-your-own
/// key / Ollama) both conform here. "AI off" isn't an engine at all — AppModel
/// simply holds none and marks verdicts `.off`.
protocol VerdictEngine: Sendable {
    func verdict(for pr: PullRequest) async throws -> Verdict

    /// Load model resources ahead of first use, so the first verdict isn't paying
    /// cold-start latency (and failing under it). No-op for engines with nothing to
    /// warm — remote and sample both take the default.
    func prewarm()

    /// How many verdicts may run at once. The on-device model serializes on the
    /// Neural Engine, so it asks for 1 — a gentle trickle that keeps heat, battery,
    /// and CPU low. Network-bound engines sit idle on I/O, so they can overlap.
    var maxConcurrency: Int { get }
}

extension VerdictEngine {
    func prewarm() {}
    var maxConcurrency: Int { 3 }
}

/// Canned verdicts with a small delay, so the loading → ready transition looks
/// real in SwiftUI previews and sample runs.
struct SampleVerdictEngine: VerdictEngine {
    var latency: Duration = .milliseconds(700)

    func verdict(for pr: PullRequest) async throws -> Verdict {
        try await Task.sleep(for: latency)
        return SampleData.verdict(for: pr)
    }
}
