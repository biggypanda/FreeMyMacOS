import Foundation
import Testing
@testable import FreeMyMacOSCore

/// A throwaway home folder under the temporary directory. Never the real home.
private struct FakeHome {
    let home: URL
    let pip: URL

    init() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("SafetyGuardTests-\(UUID().uuidString)", isDirectory: true)
        pip = home.appendingPathComponent("Library/Caches/pip", isDirectory: true)
        try FileManager.default.createDirectory(at: pip, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent("Documents", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    func path(_ relative: String) -> URL {
        home.appendingPathComponent(relative)
    }

    func pipGuard() throws -> SafetyGuard {
        try SafetyGuard(home: home, allowedRoots: [pip])
    }

    func remove() {
        try? FileManager.default.removeItem(at: home)
    }
}

@Suite struct SafetyGuardTests {
    @Test func allowsChildOfRoot() throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        try fake.pipGuard().validate(fake.path("Library/Caches/pip/x"))
    }

    @Test func rejectsRootItself() throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let guard_ = try fake.pipGuard()
        #expect(throws: SafetyError.isAllowedRootItself) {
            try guard_.validate(fake.path("Library/Caches/pip"))
        }
    }

    @Test func rejectsSibling() throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let guard_ = try fake.pipGuard()
        #expect(throws: SafetyError.outsideAllowedRoots) {
            try guard_.validate(fake.path("Library/Caches/pipX/y"))
        }
    }

    @Test func rejectsDotDotEscape() throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let guard_ = try fake.pipGuard()
        #expect(throws: SafetyError.outsideAllowedRoots) {
            try guard_.validate(fake.path("Library/Caches/pip/../../Documents/a"))
        }
    }

    @Test func rejectsPathThroughSymlinkedParent() throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let link = fake.pip.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(
            at: link, withDestinationURL: fake.path("Documents")
        )
        let guard_ = try fake.pipGuard()
        #expect(throws: SafetyError.outsideAllowedRoots) {
            try guard_.validate(link.appendingPathComponent("a"))
        }
    }

    @Test func allowsSymlinkItemItself() throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let link = fake.pip.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(
            at: link, withDestinationURL: fake.path("Documents")
        )
        try fake.pipGuard().validate(link)
    }

    @Test func rejectsShallowRoot() throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        #expect(throws: SafetyError.rootTooShallow) {
            try SafetyGuard(home: fake.home, allowedRoots: [fake.home])
        }
        #expect(throws: SafetyError.rootTooShallow) {
            try SafetyGuard(home: fake.home, allowedRoots: [fake.path("Library")])
        }
    }

    @Test func rejectsRootOutsideHome() throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let outside = fake.home.deletingLastPathComponent()
            .appendingPathComponent("Elsewhere-\(UUID().uuidString)/a/b", isDirectory: true)
        #expect(throws: SafetyError.rootTooShallow) {
            try SafetyGuard(home: fake.home, allowedRoots: [outside])
        }
    }

    @Test func acceptsTrashRoot() throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let trash = fake.path(".Trash")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let guard_ = try SafetyGuard(home: fake.home, allowedRoots: [trash])
        try guard_.validate(fake.path(".Trash/old file"))
        #expect(throws: SafetyError.isAllowedRootItself) {
            try guard_.validate(fake.path(".Trash"))
        }
    }

    @Test func acceptsAllCatalogRoots() throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let roots = TargetCatalog.all(home: fake.home, ownBundleID: "com.example.ferah")
            .flatMap(\.roots)
        let guard_ = try SafetyGuard(home: fake.home, allowedRoots: roots)
        try guard_.validate(fake.path("Library/Caches/pip/x"))
        #expect(throws: SafetyError.outsideAllowedRoots) {
            try guard_.validate(fake.path("Documents/a"))
        }
    }

    @Test func rejectsItemWhoseParentDoesNotExist() throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let guard_ = try fake.pipGuard()
        #expect(throws: SafetyError.outsideAllowedRoots) {
            try guard_.validate(fake.path("Library/Caches/pip/missing/a"))
        }
    }

    @Test func rejectsDotDotAfterSymlink() throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        let link = fake.pip.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(
            at: link, withDestinationURL: fake.path("Documents")
        )
        let guard_ = try fake.pipGuard()
        // Lexically this is pip/x, but the kernel would follow the link to home/x.
        #expect(throws: SafetyError.outsideAllowedRoots) {
            try guard_.validate(URL(fileURLWithPath: link.path + "/../x"))
        }
    }

    @Test func missingRootsDoNotThrow() throws {
        let fake = try FakeHome()
        defer { fake.remove() }
        _ = try SafetyGuard(home: fake.home, allowedRoots: [fake.path(".gradle/caches")])
    }
}
