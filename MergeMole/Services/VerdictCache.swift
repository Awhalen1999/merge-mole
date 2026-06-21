import Foundation

/// Caches AI verdicts so the model only re-runs when a PR's reviewable content
/// actually changes — not on every refresh (PLAN: "re-summarize only when its
/// diff changes"). Keyed by PR id; a content signature detects change. Persisted
/// as JSON so it survives relaunches.
final class VerdictCache {
    private struct Entry: Codable {
        let signature: String
        let verdict: Verdict
    }

    private var entries: [String: Entry]
    private let fileURL: URL?

    init() {
        fileURL = Self.makeFileURL()
        entries = Self.load(from: fileURL)
    }

    /// The cached verdict, but only if the PR's content signature still matches.
    /// Keyed by `engine` too, so different engines (on-device vs a hosted model)
    /// don't serve each other's verdicts. A mismatch (or miss) means re-run.
    func verdict(for pr: PullRequest, engine: String) -> Verdict? {
        guard let entry = entries[Self.key(pr, engine)], entry.signature == Self.signature(for: pr) else {
            return nil
        }
        return entry.verdict
    }

    func store(_ verdict: Verdict, for pr: PullRequest, engine: String) {
        entries[Self.key(pr, engine)] = Entry(signature: Self.signature(for: pr), verdict: verdict)
    }

    private static func key(_ pr: PullRequest, _ engine: String) -> String {
        "\(engine)\u{1F}\(pr.id)"
    }

    /// Write the whole cache once (called after a recompute, not per entry).
    func persist() {
        guard let fileURL, let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: Signature — exactly the inputs that feed the verdict

    private static func signature(for pr: PullRequest) -> String {
        [
            pr.title,
            String(pr.additions), String(pr.deletions), String(pr.changedFiles),
            String(pr.isDraft),
            pr.reviewState.rawValue, pr.checksState.rawValue,
            pr.headBranch, pr.baseBranch,
        ].joined(separator: "\u{1F}")   // unit separator — can't appear in the fields
    }

    // MARK: Persistence

    private static func makeFileURL() -> URL? {
        guard let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        return directory.appendingPathComponent("verdict-cache.json")
    }

    private static func load(from url: URL?) -> [String: Entry] {
        guard let url,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return [:] }
        return decoded
    }
}
