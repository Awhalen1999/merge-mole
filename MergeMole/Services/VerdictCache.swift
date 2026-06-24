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
    /// don't serve each other's verdicts. A mismatch (or miss) means re-run. The
    /// signature comes from `VerdictInput` — the same value that builds the
    /// prompt — so the cache key and the model's inputs can never drift apart.
    func verdict(for pr: PullRequest, engine: String) -> Verdict? {
        guard let entry = entries[Self.key(pr, engine)], entry.signature == VerdictInput(pr).signature else {
            return nil
        }
        return entry.verdict
    }

    func store(_ verdict: Verdict, for pr: PullRequest, engine: String) {
        entries[Self.key(pr, engine)] = Entry(signature: VerdictInput(pr).signature, verdict: verdict)
    }

    /// Drop entries for PRs that are no longer present (closed, merged, or filtered
    /// out) so the file can't grow without bound. Entries are kept across every
    /// engine tag for the PRs that *are* present, so switching engines back stays
    /// instant. Returns whether anything changed, so callers can skip a needless
    /// write. The key is `engine␟prID`, so the id is the part after the separator.
    @discardableResult
    func prune(toCurrent prs: [PullRequest]) -> Bool {
        let liveIDs = Set(prs.map(\.id))
        let before = entries.count
        entries = entries.filter { key, _ in
            guard let id = key.split(separator: "\u{1F}").last else { return false }
            return liveIDs.contains(String(id))
        }
        return entries.count != before
    }

    private static func key(_ pr: PullRequest, _ engine: String) -> String {
        "\(engine)\u{1F}\(pr.id)"
    }

    /// Write the whole cache once (called after a recompute, not per entry).
    func persist() {
        guard let fileURL, let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
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
