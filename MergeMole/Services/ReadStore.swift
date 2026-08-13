import Foundation

/// On-disk persistence for read/unread state: a map of PR id → the per-signal
/// `ReadSignature.components` the PR had when the user last marked it read. A PR
/// is "unread" when its entry is missing or any *enabled* signal's component no
/// longer matches (see `AppModel.isUnread` and Settings → Unread).
///
/// The live map is held (and observed) on `AppModel`; this type only loads and
/// saves it, mirroring how `VerdictCache` backs the observed `verdicts`. JSON in
/// Application Support, pruned to the live PR set by the caller so it can't grow.
final class ReadStore {
    private let fileURL: URL?

    init() { fileURL = Self.makeFileURL() }

    func load() -> [String: [String: String]] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return [:] }
        if let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            return decoded
        }
        // Pre-1.4 format: one flat content hash per PR. The hash matches no
        // component we track now, so carry the ids over as empty entries — "read,
        // nothing tracked yet" (a missing component always compares as a match) —
        // and the first sync's reconcile backfills fresh components. The one-time
        // cost: changes from before the upgrade won't re-flag these PRs.
        if let legacy = try? JSONDecoder().decode([String: String].self, from: data) {
            return legacy.mapValues { _ in [:] }
        }
        return [:]
    }

    func save(_ components: [String: [String: String]]) {
        guard let fileURL, let data = try? JSONEncoder().encode(components) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Delete the file (factory reset).
    func clear() {
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
    }

    /// `~/Library/Application Support/MergeMole/read-state.json` — alongside the
    /// verdict cache, out of the shared Application Support root.
    private static func makeFileURL() -> URL? {
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        let directory = support.appendingPathComponent("MergeMole", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("read-state.json")
    }
}
