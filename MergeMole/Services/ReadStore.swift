import Foundation

/// On-disk persistence for read/unread state: a map of PR id → the content
/// `signature` the PR had when the user last marked it read. A PR is "unread" when
/// this stored signature is missing or no longer matches its current signature —
/// the *same* `VerdictInput.signature` the verdict cache uses, so a PR re-surfaces
/// as unread on exactly the changes that re-run the AI (commit, CI, review, labels).
///
/// The live map is held (and observed) on `AppModel`; this type only loads and
/// saves it, mirroring how `VerdictCache` backs the observed `verdicts`. JSON in
/// Application Support, pruned to the live PR set by the caller so it can't grow.
final class ReadStore {
    private let fileURL: URL?

    init() { fileURL = Self.makeFileURL() }

    func load() -> [String: String] {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }

    func save(_ signatures: [String: String]) {
        guard let fileURL, let data = try? JSONEncoder().encode(signatures) else { return }
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
