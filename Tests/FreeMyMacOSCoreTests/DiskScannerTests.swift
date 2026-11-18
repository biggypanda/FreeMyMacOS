import Foundation
import Testing
@testable import FreeMyMacOSCore

/// A throwaway folder under the temporary directory. Never the real home.
private struct FakeTree {
    let base: URL

    init() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiskScannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    func dir(_ relative: String) throws -> URL {
        let url = base.appendingPathComponent(relative, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    func file(_ relative: String, bytes: Int) throws -> URL {
        let url = base.appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(repeating: 0xAB, count: bytes).write(to: url)
        return url
    }

    func remove() {
        try? FileManager.default.removeItem(at: base)
    }
}

private func target(
    _ roots: [URL], excludedNames: Set<String> = [], excludedPrefixes: [String] = []
) -> CleanTarget {
    CleanTarget(
        id: "test.target", title: "Test", detail: "Test target.", symbol: "folder",
        group: .system, tier: .safe, roots: roots,
        excludedNames: excludedNames, excludedPrefixes: excludedPrefixes
    )
}

@Suite struct DiskScannerTests {
    @Test func sumsAllocatedSizes() async throws {
        let tree = try FakeTree()
        defer { tree.remove() }
        let rootA = try tree.dir("a")
        let rootB = try tree.dir("b")
        try tree.file("a/one.bin", bytes: 100_000)
        try tree.file("a/nested/two.bin", bytes: 200_000)
        try tree.file("b/three.bin", bytes: 300_000)

        let result = await DiskScanner().scan(target([rootA, rootB]))

        #expect(result.targetID == "test.target")
        #expect(result.status == .ok)
        #expect(result.bytes >= 600_000)
        #expect(result.itemCount == 3)
    }

    @Test func missingRootsReportMissing() async throws {
        let tree = try FakeTree()
        defer { tree.remove() }
        let roots = [
            tree.base.appendingPathComponent("nope", isDirectory: true),
            tree.base.appendingPathComponent("also/nope", isDirectory: true),
        ]

        let result = await DiskScanner().scan(target(roots))

        #expect(result.status == .missing)
        #expect(result.bytes == 0)
        #expect(result.itemCount == 0)
        #expect(result.topItems.isEmpty)
        #expect(try target(roots).deletableItems().isEmpty)
    }

    @Test func excludedChildrenNotCounted() async throws {
        let tree = try FakeTree()
        defer { tree.remove() }
        let root = try tree.dir("caches")
        let kept = try tree.file("caches/keep/big.bin", bytes: 2_000_000)
        let apple = try tree.file("caches/com.apple.thing/big.bin", bytes: 2_000_000)
        try tree.file("caches/junk.bin", bytes: 50_000)
        let subject = target([root], excludedNames: ["keep"], excludedPrefixes: ["com.apple."])

        let result = await DiskScanner().scan(subject)
        let items = try subject.deletableItems().map(\.lastPathComponent)

        #expect(result.status == .ok)
        #expect(result.itemCount == 1)
        #expect(result.bytes < 1_000_000)
        #expect(items == ["junk.bin"])
        #expect(!items.contains(kept.deletingLastPathComponent().lastPathComponent))
        #expect(!items.contains(apple.deletingLastPathComponent().lastPathComponent))
    }

    @Test func topItemsAreLargestFiveSortedDescending() async throws {
        let tree = try FakeTree()
        defer { tree.remove() }
        let root = try tree.dir("root")
        for (index, size) in [10_000, 70_000, 30_000, 50_000, 20_000, 60_000, 40_000].enumerated() {
            try tree.file("root/item\(index).bin", bytes: size)
        }
        try tree.file("root/keep.bin", bytes: 500_000)
        let subject = target([root], excludedNames: ["keep.bin"])

        let result = await DiskScanner().scan(subject)

        #expect(result.itemCount == 7)
        #expect(result.topItems.count == 5)
        let sizes = result.topItems.map(\.bytes)
        #expect(sizes == sizes.sorted(by: >))
        #expect(result.topItems.first?.name == "item1.bin")
        #expect(sizes.reduce(0, +) <= result.bytes)
        #expect(!result.topItems.contains { $0.name == "keep.bin" })
    }

    @Test func symlinkNotFollowed() async throws {
        let tree = try FakeTree()
        defer { tree.remove() }
        let root = try tree.dir("root")
        let outsideFile = try tree.file("outside/big.bin", bytes: 1_000_000)
        let outsideDir = try tree.dir("outside")
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("fileLink"), withDestinationURL: outsideFile
        )
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("dirLink"), withDestinationURL: outsideDir
        )
        try FileManager.default.createSymbolicLink(
            at: try tree.dir("root/sub").appendingPathComponent("nestedLink"),
            withDestinationURL: outsideDir
        )

        let result = await DiskScanner().scan(target([root]))

        #expect(result.status == .ok)
        #expect(result.itemCount == 3)
        #expect(result.bytes < 100_000)
        #expect(allocatedSize(of: root.appendingPathComponent("fileLink")) < 100_000)
    }

    @Test func symlinkedRootIsTreatedAsMissing() async throws {
        let tree = try FakeTree()
        defer { tree.remove() }
        // A fake home whose cache root is a link to a folder outside that home.
        let home = try tree.dir("home")
        try tree.file("outside/big.bin", bytes: 1_000_000)
        let outside = try tree.dir("outside")
        let caches = try tree.dir("home/Library/Caches")
        let linkedRoot = caches.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: caches.appendingPathComponent("linked"), withDestinationURL: outside
        )
        // Both spellings: with the trailing slash the catalog uses, and without.
        let plainRoot = caches.appendingPathComponent("linked", isDirectory: false)

        for root in [linkedRoot, plainRoot] {
            let subject = target([root])
            let result = await DiskScanner(home: home).scan(subject)

            #expect(result.status == .missing)
            #expect(result.bytes == 0)
            #expect(result.itemCount == 0)
            #expect(result.topItems.isEmpty)
            #expect(try subject.deletableItems().isEmpty)
        }
        #expect(FileManager.default.fileExists(atPath: outside.appendingPathComponent("big.bin").path))
    }

    @Test func unreadableRootReportsPermissionDenied() async throws {
        let tree = try FakeTree()
        defer { tree.remove() }
        let root = try tree.dir("locked")
        try tree.file("locked/secret.bin", bytes: 100_000)
        let fm = FileManager.default
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: root.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path) }

        let result = await DiskScanner().scan(target([root]))

        #expect(result.status == .permissionDenied)
        #expect(result.bytes == 0)
        #expect(result.deniedRoots == [root])
        #expect(throws: (any Error).self) { try target([root]).deletableItems() }
    }

    @Test func unreadableRootWithReadableBytesIsOk() async throws {
        let tree = try FakeTree()
        defer { tree.remove() }
        let locked = try tree.dir("locked")
        let open = try tree.dir("open")
        try tree.file("open/data.bin", bytes: 100_000)
        let fm = FileManager.default
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        let result = await DiskScanner().scan(target([locked, open]))

        #expect(result.status == .ok)
        #expect(result.bytes >= 100_000)
        #expect(result.itemCount == 1)
        // The row stays usable, and the view can still ask for access to the locked root.
        #expect(result.deniedRoots == [locked])
    }

    @Test func readableRootsReportNoDeniedRoots() async throws {
        let tree = try FakeTree()
        defer { tree.remove() }
        let open = try tree.dir("open")
        try tree.file("open/data.bin", bytes: 10_000)

        let result = await DiskScanner().scan(target([open]))

        #expect(result.status == .ok)
        #expect(result.deniedRoots.isEmpty)
    }

    @Test func multiRootNamesAreHomeRelative() async throws {
        let tree = try FakeTree()
        defer { tree.remove() }
        let rootA = try tree.dir("home/.npm/_cacache")
        let rootB = try tree.dir("home/Library/Caches/Yarn")
        try tree.file("home/.npm/_cacache/x.bin", bytes: 1_000)
        try tree.file("home/Library/Caches/Yarn/y.bin", bytes: 2_000)
        let scanner = DiskScanner(home: tree.base.appendingPathComponent("home"))

        let multi = await scanner.scan(target([rootA, rootB]))
        let single = await scanner.scan(target([rootA]))

        #expect(Set(multi.topItems.map(\.name))
                == ["~/.npm/_cacache/x.bin", "~/Library/Caches/Yarn/y.bin"])
        #expect(single.topItems.map(\.name) == ["x.bin"])
    }
}
