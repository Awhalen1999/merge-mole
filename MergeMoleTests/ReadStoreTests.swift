import Foundation
import Testing
@testable import MergeMole

/// Disk persistence for read state: the real JSON round-trip on a scratch file,
/// plus the v1 → v2 migration and the failure modes (garbage, missing file).
@Suite struct ReadStoreTests {

    @Test func roundTripsComponentsThroughDisk() {
        let url = tempFileURL("read-state.json")
        let components = ["PR_1": ["commits": "abc", "review": "approved"],
                          "PR_2": [:]]
        ReadStore(fileURL: url).save(components)
        #expect(ReadStore(fileURL: url).load() == components)
    }

    /// Pre-1.4 format: one flat hash per PR. Ids carry over as empty entries —
    /// "read, nothing tracked yet" — and reconcile backfills on the next sync.
    @Test func migratesV1SingleHashEntriesAsRead() throws {
        let url = tempFileURL("read-state.json")
        try Data(#"{"PR_1": "deadbeef", "PR_2": "cafe"}"#.utf8).write(to: url)
        let loaded = ReadStore(fileURL: url).load()
        #expect(loaded == ["PR_1": [:], "PR_2": [:]])
    }

    @Test func garbageFileLoadsEmptyInsteadOfCrashing() throws {
        let url = tempFileURL("read-state.json")
        try Data("not json {{{".utf8).write(to: url)
        #expect(ReadStore(fileURL: url).load().isEmpty)
    }

    @Test func missingFileLoadsEmpty() {
        #expect(ReadStore(fileURL: tempFileURL("never-written.json")).load().isEmpty)
    }

    @Test func clearDeletesTheFile() {
        let url = tempFileURL("read-state.json")
        let store = ReadStore(fileURL: url)
        store.save(["PR_1": ["commits": "abc"]])
        store.clear()
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}
