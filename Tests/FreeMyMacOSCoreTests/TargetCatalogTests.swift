import Foundation
import Testing
@testable import FreeMyMacOSCore

@Test func catalogMatchesSpecTable() {
    let home = URL(fileURLWithPath: "/Users/test")
    let all = TargetCatalog.all(home: home, ownBundleID: "com.example.ferah")
    #expect(all.map(\.id) == ["xcode.derivedData","xcode.simulatorCaches","xcode.deviceSupport",
        "xcode.archives","swiftpm.cache","node.cache","python.cache","cocoapods.cache",
        "gradle.cache","homebrew.cache","browser.caches","user.caches","user.logs","trash"])
    #expect(all.filter { $0.tier == .careful }.map(\.id) == ["xcode.deviceSupport","xcode.archives","trash"])
    #expect(all.allSatisfy { $0.roots.allSatisfy { $0.path.hasPrefix("/Users/test/") } })
}

@Test func userCachesExcludesOtherTargetsAndApple() {
    let t = TargetCatalog.all(home: URL(fileURLWithPath: "/Users/test"), ownBundleID: "com.example.ferah")
        .first { $0.id == "user.caches" }!
    #expect(t.excludedNames.isSuperset(of: ["org.swift.swiftpm","Yarn","pip","CocoaPods","Homebrew",
        "Google","Firefox","company.thebrowser.Browser","com.example.ferah"]))
    #expect(t.excludedPrefixes == ["com.apple."])
}
