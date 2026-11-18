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
            _ group: CleanGroup, _ tier: CleanTier, _ relativeRoots: [String],
            guards: [AppGuard] = []
        ) -> CleanTarget {
            CleanTarget(
                id: id, title: CoreText.catalog(title), detail: CoreText.catalog(detail), symbol: symbol,
                group: group, tier: tier, roots: relativeRoots.map(root), appGuards: guards
            )
        }

        func appGuard(_ name: String, _ bundleIDs: [String], _ folder: String) -> AppGuard {
            AppGuard(appName: name, bundleIDs: bundleIDs, folder: root(folder))
        }

        let support = "Library/Application Support"
        let electronCaches = ["CachedData", "CachedExtensionVSIXs", "Cache", "Code Cache", "GPUCache"]
        let editorRoots = ["Code", "Cursor"].flatMap { app in
            electronCaches.map { "\(support)/\(app)/\($0)" }
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
            make("xcode.previews", "Xcode Previews",
                 "Builds Xcode made for SwiftUI previews; it rebuilds them, slowly, the next time a preview opens.",
                 "rectangle.on.rectangle", .developer, .careful,
                 ["Library/Developer/Xcode/UserData/Previews"]),
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
            make("cargo.registry", "Cargo Registry",
                 "Downloaded Rust crates that Cargo fetches again when a project needs them.",
                 "shippingbox.circle", .developer, .safe,
                 [".cargo/registry/cache", ".cargo/registry/src"]),
            make("bun.cache", "Bun Cache",
                 "Package downloads Bun keeps, which it refills on the next install.",
                 "hare", .developer, .safe,
                 [".bun/install/cache"]),
            make("uv.cache", "uv Cache",
                 "Python packages the uv tool downloaded, which it fetches again when needed.",
                 "bolt", .developer, .safe,
                 [".cache/uv"]),
            make("pub.cache", "Dart Pub Cache",
                 "Downloaded Dart and Flutter packages; run pub get in a project to fetch them again.",
                 "bird", .developer, .safe,
                 [".pub-cache/hosted"]),
            make("playwright.browsers", "Playwright Browsers",
                 "Browser builds Playwright downloaded for tests; run npx playwright install to get them back.",
                 "theatermasks", .developer, .careful,
                 ["Library/Caches/ms-playwright"]),
            make("puppeteer.browsers", "Puppeteer Browsers",
                 "Browser builds Puppeteer downloaded for tests, fetched again on the next install.",
                 "theatermask.and.paintbrush", .developer, .careful,
                 [".cache/puppeteer"]),
            make("maven.repository", "Maven Repository",
                 "Downloaded Java libraries; anything you installed locally with mvn install exists only here.",
                 "building.columns", .developer, .careful,
                 [".m2/repository"]),
            make("huggingface.hub", "Hugging Face Models",
                 "Downloaded AI models, which can be very large and slow to download again.",
                 "brain", .developer, .careful,
                 [".cache/huggingface/hub"]),
            make("editor.caches", "VS Code / Cursor Caches",
                 "Caches the editors rebuild on their own. Quit the editor first; while it is open they are skipped.",
                 "chevron.left.slash.chevron.right", .developer, .safe,
                 editorRoots,
                 guards: [
                    appGuard("VS Code", ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"], "\(support)/Code"),
                    appGuard("Cursor", ["com.todesktop.230313mzl4w4u92"], "\(support)/Cursor"),
                 ]),
            make("browser.caches", "Browser Caches",
                 "Saved copies of web pages and images that browsers download again as you browse.",
                 "globe", .browsers, .safe,
                 ["Library/Caches/Google/Chrome", "Library/Caches/com.apple.Safari",
                  "Library/Caches/Firefox", "Library/Caches/company.thebrowser.Browser"]),
            make("chat.caches", "Slack / Discord Caches",
                 "Cached images and files the chat apps download again. Quit the app first; while it is open they are skipped.",
                 "bubble.left.and.bubble.right", .apps, .safe,
                 ["\(support)/Slack/Cache", "\(support)/Slack/Service Worker/CacheStorage",
                  "\(support)/discord/Cache", "\(support)/discord/Code Cache"],
                 guards: [
                    appGuard("Slack", ["com.tinyspeck.slackmacgap"], "\(support)/Slack"),
                    appGuard("Discord", ["com.hnc.Discord"], "\(support)/discord"),
                 ]),
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
            title: CoreText.catalog("App Caches"),
            detail: CoreText.catalog("Temporary files apps keep to load faster, which they recreate as they need them."),
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
