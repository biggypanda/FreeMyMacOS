import Foundation

/// The fixed list of cleanable locations. Paths never come from the user.
public enum TargetCatalog {
    private static let userCachesPath = "Library/Caches"

    public static func all(home: URL, ownBundleID: String) -> [CleanTarget] {
        let home = home.standardizedFileURL

        func root(_ relative: String) -> URL {
            home.appendingPathComponent(relative, isDirectory: true).standardizedFileURL
        }

        func make(
            _ id: String, _ title: String, _ detail: String, _ symbol: String,
            _ group: CleanGroup, _ tier: CleanTier, _ relativeRoots: [String]
        ) -> CleanTarget {
            CleanTarget(
                id: id, title: title, detail: detail, symbol: symbol,
                group: group, tier: tier, roots: relativeRoots.map(root)
            )
        }

        let before: [CleanTarget] = [
            make("xcode.derivedData", "Xcode DerivedData",
                 "Intermediate build products and indexes that Xcode recreates the next time you build.",
                 "hammer", .developer, .safe,
                 ["Library/Developer/Xcode/DerivedData"]),
            make("xcode.simulatorCaches", "Simulator Caches",
                 "Cached data for the iOS Simulator that it rebuilds on demand when it next runs.",
                 "iphone", .developer, .safe,
                 ["Library/Developer/CoreSimulator/Caches"]),
            make("xcode.deviceSupport", "iOS Device Support",
                 "Debug symbols copied from connected devices, which Xcode copies again the next time that device is connected.",
                 "cable.connector", .developer, .careful,
                 ["Library/Developer/Xcode/iOS DeviceSupport"]),
            make("xcode.archives", "Xcode Archives",
                 "App builds you archived for distribution, worth keeping only if you still need to symbolicate or resubmit them.",
                 "archivebox", .developer, .careful,
                 ["Library/Developer/Xcode/Archives"]),
            make("swiftpm.cache", "SwiftPM Cache",
                 "Downloaded Swift package sources that SwiftPM fetches again when a project needs them.",
                 "shippingbox", .developer, .safe,
                 ["Library/Caches/org.swift.swiftpm"]),
            make("node.cache", "npm / Yarn / pnpm",
                 "Package download caches for JavaScript tools, which are refilled automatically on the next install.",
                 "curlybraces", .developer, .safe,
                 [".npm/_cacache", "Library/Caches/Yarn", "Library/pnpm/store"]),
            make("python.cache", "pip Cache",
                 "Downloaded Python packages and wheels that pip fetches again when you next install them.",
                 "chevron.left.forwardslash.chevron.right", .developer, .safe,
                 ["Library/Caches/pip"]),
            make("cocoapods.cache", "CocoaPods Cache",
                 "Downloaded pod sources that CocoaPods fetches again on the next pod install.",
                 "cube", .developer, .safe,
                 ["Library/Caches/CocoaPods"]),
            make("gradle.cache", "Gradle Caches",
                 "Downloaded dependencies and build caches that Gradle restores on the next build.",
                 "gearshape.2", .developer, .safe,
                 [".gradle/caches"]),
            make("homebrew.cache", "Homebrew Downloads",
                 "Installer files Homebrew already used, which it downloads again only if it needs them.",
                 "mug", .developer, .safe,
                 ["Library/Caches/Homebrew"]),
            make("browser.caches", "Browser Caches",
                 "Saved copies of web pages and images that browsers download again as you browse.",
                 "globe", .browsers, .safe,
                 ["Library/Caches/Google/Chrome", "Library/Caches/com.apple.Safari",
                  "Library/Caches/Firefox", "Library/Caches/company.thebrowser.Browser"]),
        ]

        let after: [CleanTarget] = [
            make("user.logs", "User Logs",
                 "Diagnostic log files written by apps, which they start fresh when needed.",
                 "doc.text", .system, .safe,
                 ["Library/Logs"]),
            make("trash", "Trash",
                 "Items you already moved to the Trash, which are removed for good when it is emptied.",
                 "trash", .system, .careful,
                 [".Trash"]),
        ]

        let cachesRoot = root(userCachesPath)
        let userCaches = CleanTarget(
            id: "user.caches",
            title: "App Caches",
            detail: "Temporary files apps keep to load faster, which they recreate as they need them.",
            symbol: "internaldrive",
            group: .system,
            tier: .safe,
            roots: [cachesRoot],
            excludedNames: excludedCacheNames(
                in: cachesRoot, otherTargets: before + after, ownBundleID: ownBundleID
            ),
            excludedPrefixes: ["com.apple."]
        )

        return before + [userCaches] + after
    }

    /// Children of `cachesRoot` that are another target's root or an ancestor of one,
    /// plus the app's own cache folder.
    private static func excludedCacheNames(
        in cachesRoot: URL, otherTargets: [CleanTarget], ownBundleID: String
    ) -> Set<String> {
        let base = cachesRoot.pathComponents
        var names: Set<String> = [ownBundleID]
        for target in otherTargets {
            for root in target.roots {
                let components = root.pathComponents
                guard components.count > base.count,
                      Array(components.prefix(base.count)) == base
                else { continue }
                names.insert(components[base.count])
            }
        }
        return names
    }
}
