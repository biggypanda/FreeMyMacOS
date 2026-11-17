import Foundation
import Testing
@testable import FreeMyMacOSCore

/// A throwaway folder under the temporary directory holding a fake home and an
/// "outside" folder next to it. Never the real home.
private struct FakeHome {
    let base: URL
    let home: URL
    let outside: URL
    let pip: URL

    init() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanerTests-\(UUID().uuidString)", isDirectory: true)
        home = base.appendingPathComponent("home", isDirectory: true)
        outside = base.appendingPathComponent("outside", isDirectory: true)
        pip = home.appendingPathComponent("Library/Caches/pip", isDirectory: true)
        try FileManager.default.createDirectory(at: pip, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    }

    func dir(_ relative: String) throws -> URL {
        let url = home.appendingPathComponent(relative, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    func file(_ relative: String, bytes: Int, in folder: URL? = nil) throws -> URL {
        let url = (folder ?? home).appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(repeating: 0xAB, count: bytes).write(to: url)
        return url
    }

    func guardFor(_ roots: [URL]) throws -> SafetyGuard {
        try SafetyGuard(home: home, allowedRoots: roots)
    }

    func remove() {
        try? FileManager.default.removeItem(at: base)
    }
}

private func target(_ roots: [URL], excludedNames: Set<String> = []) -> CleanTarget {
    CleanTarget(
        id: "test.target", title: "Test", detail: "Test target.", symbol: "folder",
        group: .system, tier: .safe, roots: roots, excludedNames: excludedNames
    )
}

private func exists(_ url: URL) -> Bool {
    var info = stat()
    return lstat(url.path, &info) == 0
}

/// Path with symlinks resolved (`/var` vs `/private/var`), for comparing reported paths.
private func canonical(_ path: String) -> String {
    URL(fileURLWithPath: path).resolvingSymlinksInPath().path
}

private func children(of url: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
}

@Suite struct CleanerTests {
    @Test func deletesChildrenKeepsRoot() async throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        try fake.file("Library/Caches/pip/one.bin", bytes: 100_000)
        try fake.file("Library/Caches/pip/nested/two.bin", bytes: 200_000)
        let expected = allocatedSize(of: fake.pip.appendingPathComponent("one.bin"))
            + allocatedSize(of: fake.pip.appendingPathComponent("nested"))

        let report = await Cleaner(guard: try fake.guardFor([fake.pip]))
            .clean(target([fake.pip]))

        #expect(report.targetID == "test.target")
        #expect(report.failures.isEmpty)
        #expect(report.freedBytes > 0)
        #expect(report.freedBytes == expected)
        #expect(exists(fake.pip))
        #expect(try children(of: fake.pip).isEmpty)
    }

    @Test func dryRunDeletesNothing() async throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let one = try fake.file("Library/Caches/pip/one.bin", bytes: 100_000)
        let two = try fake.file("Library/Caches/pip/nested/two.bin", bytes: 200_000)
        let expected = allocatedSize(of: one)
            + allocatedSize(of: fake.pip.appendingPathComponent("nested"))

        let report = await Cleaner(guard: try fake.guardFor([fake.pip]), dryRun: true)
            .clean(target([fake.pip]))

        #expect(report.failures.isEmpty)
        #expect(report.freedBytes > 0)
        #expect(report.freedBytes == expected)
        #expect(exists(one))
        #expect(exists(two))
    }

    @Test func symlinkRemovedTargetUntouched() async throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let secret = try fake.file("secret.bin", bytes: 50_000, in: fake.outside)
        let original = try Data(contentsOf: secret)
        let link = fake.pip.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: secret)
        let folderLink = fake.pip.appendingPathComponent("folderLink")
        try FileManager.default.createSymbolicLink(at: folderLink, withDestinationURL: fake.outside)

        let report = await Cleaner(guard: try fake.guardFor([fake.pip]))
            .clean(target([fake.pip]))

        #expect(report.failures.isEmpty)
        #expect(!exists(link))
        #expect(!exists(folderLink))
        #expect(try Data(contentsOf: secret) == original)
        #expect(try children(of: fake.outside) == ["secret.bin"])
    }

    @Test func excludedChildrenSurvive() async throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let keep = try fake.file("Library/Caches/pip/keep.bin", bytes: 10_000)
        let gone = try fake.file("Library/Caches/pip/gone.bin", bytes: 10_000)
        let goneBytes = allocatedSize(of: gone)

        let report = await Cleaner(guard: try fake.guardFor([fake.pip]))
            .clean(target([fake.pip], excludedNames: ["keep.bin"]))

        #expect(report.failures.isEmpty)
        #expect(exists(keep))
        #expect(!exists(gone))
        #expect(report.freedBytes == goneBytes)
    }

    @Test func continuesAfterFailure() async throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let fm = FileManager.default
        let first = try fake.file("Library/Caches/pip/a.bin", bytes: 100_000)
        let last = try fake.file("Library/Caches/pip/z.bin", bytes: 300_000)
        // "mixed" holds a loose file and a read-only subfolder whose file cannot be unlinked.
        // Named so removal usually reaches the loose file first: a partial delete.
        let mixed = fake.pip.appendingPathComponent("mixed", isDirectory: true)
        let loose = try fake.file("aloose.bin", bytes: 40_000, in: mixed)
        let locked = mixed.appendingPathComponent("zlocked", isDirectory: true)
        let kept = try fake.file("kept.bin", bytes: 70_000, in: locked)
        let otherBytes = allocatedSize(of: first) + allocatedSize(of: last)
        let looseBytes = allocatedSize(of: loose)
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        let report = await Cleaner(guard: try fake.guardFor([fake.pip]))
            .clean(target([fake.pip]))

        #expect(report.failures.count == 1)
        #expect(report.failures.first.map { canonical($0.path) } == canonical(mixed.path))
        #expect(report.failures.first?.reason.isEmpty == false)
        #expect(!exists(first))
        #expect(!exists(last))
        #expect(exists(kept))
        // Only bytes that are really gone: the other children, plus the loose file
        // if removal got to it before failing. The kept file is never counted.
        let freedLoose = exists(loose) ? 0 : looseBytes
        #expect(report.freedBytes == otherBytes + freedLoose)
    }

    @Test func refusesItemsOutsideGuard() async throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let one = try fake.file("Library/Caches/pip/one.bin", bytes: 10_000)
        let two = try fake.file("Library/Caches/pip/two.bin", bytes: 10_000)
        let otherRoot = try fake.dir("Library/Caches/other")

        let report = await Cleaner(guard: try fake.guardFor([otherRoot]))
            .clean(target([fake.pip]))

        #expect(report.freedBytes == 0)
        #expect(exists(one))
        #expect(exists(two))
        #expect(Set(report.failures.map { canonical($0.path) }) == [canonical(one.path), canonical(two.path)])
    }

    @Test func refusesItemsOfSymlinkedRootPointingOutsideHome() async throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let secret = try fake.file("secret.bin", bytes: 50_000, in: fake.outside)
        let evil = fake.home.appendingPathComponent("Library/Caches/evil", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: evil, withDestinationURL: fake.outside)

        // A guard cannot even be built from such a root.
        #expect(throws: SafetyError.rootTooShallow) {
            try fake.guardFor([evil])
        }

        // With a guard over its parent, an item reached through the link is refused...
        let caches = fake.home.appendingPathComponent("Library/Caches", isDirectory: true)
        let cachesGuard = try fake.guardFor([caches])
        #expect(throws: SafetyError.outsideAllowedRoots) {
            try cachesGuard.validate(evil.appendingPathComponent("secret.bin"))
        }

        // ...and cleaning such a root deletes nothing. (Foundation refuses to list a
        // symlinked folder, so the root yields no items; any item it did yield is refused.)
        let report = await Cleaner(guard: cachesGuard).clean(target([evil]))

        #expect(report.freedBytes == 0)
        #expect(report.failures.allSatisfy { $0.reason == "Outside the allowed folders" })
        #expect(exists(secret))
        #expect(try children(of: fake.outside) == ["secret.bin"])
    }

    @Test func itemThatVanishedBeforeRemovalCreditsNothing() async throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        try fake.file("Library/Caches/pip/gone.bin", bytes: 100_000)

        // Something else deletes the item between listing and removal.
        let cleaner = Cleaner(guard: try fake.guardFor([fake.pip])) { url in
            try FileManager.default.removeItem(at: url)
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: url.path])
        }
        let report = await cleaner.clean(target([fake.pip]))

        #expect(report.freedBytes == 0)
        #expect(report.failures.map(\.reason) == ["No longer exists"])
    }

    @Test func missingRootIsNotAFailure() async throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let missing = fake.home.appendingPathComponent("Library/Caches/nope", isDirectory: true)
        try fake.file("Library/Caches/pip/one.bin", bytes: 10_000)

        let report = await Cleaner(guard: try fake.guardFor([missing, fake.pip]))
            .clean(target([missing, fake.pip]))

        #expect(report.failures.isEmpty)
        #expect(report.freedBytes > 0)
        #expect(try children(of: fake.pip).isEmpty)
    }

    @Test func unreadableRootDoesNotStopOthers() async throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let fm = FileManager.default
        let denied = try fake.dir("Library/Caches/denied")
        try fake.file("Library/Caches/denied/x.bin", bytes: 10_000)
        try fake.file("Library/Caches/pip/one.bin", bytes: 10_000)
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: denied.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: denied.path) }

        let report = await Cleaner(guard: try fake.guardFor([denied, fake.pip]))
            .clean(target([denied, fake.pip]))

        #expect(report.failures.map { canonical($0.path) } == [canonical(denied.path)])
        #expect(report.freedBytes > 0)
        #expect(try children(of: fake.pip).isEmpty)
    }
}
