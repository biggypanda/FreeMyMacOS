import Foundation
import Testing
@testable import FreeMyMacOSCore

@Test func catalogMatchesSpecTable() {
    let home = URL(fileURLWithPath: "/Users/test")
    let all = TargetCatalog.all(home: home, ownBundleID: "com.example.ferah")
    #expect(all.map(\.id) == ["xcode.derivedData","xcode.simulatorCaches","xcode.deviceSupport",
        "xcode.archives","xcode.previews","swiftpm.cache","node.cache","python.cache","cocoapods.cache",
        "gradle.cache","homebrew.cache","cargo.registry","bun.cache","uv.cache","pub.cache",
        "playwright.browsers","puppeteer.browsers","maven.repository","huggingface.hub",
        "editor.caches","browser.caches","chat.caches","user.caches","user.logs","trash"])
    #expect(all.filter { $0.tier == .careful }.map(\.id) == ["xcode.deviceSupport","xcode.archives",
        "xcode.previews","playwright.browsers","puppeteer.browsers","maven.repository",
        "huggingface.hub","trash"])
    #expect(Set(all.map(\.id)).count == all.count)
    #expect(all.allSatisfy { $0.roots.allSatisfy { $0.path.hasPrefix("/Users/test/") } })
}

@Test func userCachesExcludesOtherTargetsAndApple() {
    let t = TargetCatalog.all(home: URL(fileURLWithPath: "/Users/test"), ownBundleID: "com.example.ferah")
        .first { $0.id == "user.caches" }!
    #expect(t.excludedNames.isSuperset(of: ["org.swift.swiftpm","Yarn","pip","CocoaPods","Homebrew",
        "Google","Firefox","company.thebrowser.Browser","com.example.ferah"]))
    #expect(t.excludedPrefixes == ["com.apple."])
}

@Test func everyRootIsDeepEnoughForTheSafetyGuard() throws {
    let home = URL(fileURLWithPath: "/Users/test")
    for target in TargetCatalog.all(home: home, ownBundleID: "com.example.ferah") {
        for root in target.roots {
            let depth = root.pathComponents.count - home.pathComponents.count
            #expect(depth >= 2 || root.lastPathComponent == ".Trash", "\(root.path)")
        }
    }
}

@Test func playwrightIsItsOwnRowNotPartOfAppCaches() {
    let all = TargetCatalog.all(home: URL(fileURLWithPath: "/Users/test"), ownBundleID: "com.example.ferah")
    let caches = all.first { $0.id == "user.caches" }!
    #expect(caches.excludedNames.contains("ms-playwright"))
}

@Test func appDataRowsAreGuardedByTheirApps() {
    let all = TargetCatalog.all(home: URL(fileURLWithPath: "/Users/test"), ownBundleID: "com.example.ferah")
    for id in ["editor.caches", "chat.caches"] {
        let target = all.first { $0.id == id }!
        #expect(!target.appGuards.isEmpty)
        // Every root is covered by exactly one guard.
        for root in target.roots {
            #expect(target.appGuards.filter { $0.covers(root) }.count == 1, "\(root.path)")
        }
    }
    let editors = all.first { $0.id == "editor.caches" }!
    let vscodeRoot = editors.roots.first { $0.path.contains("/Code/") }!
    #expect(editors.appGuard(for: vscodeRoot, running: ["com.microsoft.VSCode"])?.appName == "VS Code")
    #expect(editors.appGuard(for: vscodeRoot, running: ["com.todesktop.230313mzl4w4u92"]) == nil)
}
