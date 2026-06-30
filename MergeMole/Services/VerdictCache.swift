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
        Self.removeLegacyRootFile()
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

    /// Drop entries that are no longer valid: their PR is gone (closed/merged/filtered
    /// out), OR they were written under a superseded prompt `version`. Entries for live
    /// PRs *on the current version* are kept across every engine tag, so switching
    /// engines back stays instant — but a version bump no longer leaves dead entries
    /// behind for still-open PRs. Returns whether anything changed, so callers can skip
    /// a needless write. The key is `engineTag␟prID`, and `engineTag` ends in `@<version>`.
    @discardableResult
    func prune(toCurrent prs: [PullRequest], version: String) -> Bool {
        let liveIDs = Set(prs.map(\.id))
        let before = entries.count
        entries = entries.filter { key, _ in
            let parts = key.split(separator: "\u{1F}", maxSplits: 1)
            guard parts.count == 2, liveIDs.contains(String(parts[1])) else { return false }
            return parts[0].hasSuffix("@\(version)")   // current prompt version only
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

    /// Empty the cache and delete its file (factory reset).
    func clear() {
        entries = [:]
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
    }

    // MARK: Persistence

    /// `~/Library/Application Support/MergeMole/verdict-cache.json`. The `MergeMole`
    /// subfolder keeps our file out of the shared Application Support root.
    private static func makeFileURL() -> URL? {
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        let directory = support.appendingPathComponent("MergeMole", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("verdict-cache.json")
    }

    /// Pre-1.0 builds wrote the cache to the Application Support *root*. Sweep that
    /// stray file so it doesn't linger after the move into the subfolder.
    private static func removeLegacyRootFile() {
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return }
        try? FileManager.default.removeItem(at: support.appendingPathComponent("verdict-cache.json"))
    }

    private static func load(from url: URL?) -> [String: Entry] {
        guard let url,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return [:] }
        return decoded
    }
}
