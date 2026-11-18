import AppKit
import Foundation
import SwiftUI
import Testing
@testable import FreeMyMacOS
@testable import FreeMyMacOSCore

private let en = Locale(identifier: "en_US")
private let tr = Locale(identifier: "tr_TR")
private let de = Locale(identifier: "de_DE")

@Suite struct BytePartsTests {
    @Test func heroSplitsNumberAndUnitInEveryLanguage() {
        let english = ByteParts(bytes: 23_940_000_000, locale: en)
        #expect(english.text == "23.94")
        #expect(english.unit == "GB")
        for locale in [tr, de] {
            let parts = ByteParts(bytes: 23_940_000_000, locale: locale)
            #expect(parts.text == "23,94")
            #expect(parts.number == 23.94)
            #expect(parts.unit == "GB")
            // The clean flow redraws the number in the same format.
            #expect(parts.formatted(11.5) == "11,50")
        }
    }

    @Test func zeroHasNoUnit() {
        #expect(ByteParts(bytes: 0, locale: tr).unit == nil)
        #expect(ByteParts(bytes: 0, locale: tr).text == "0")
    }

    @Test func memoryUsageUsesTheLocalesNumbers() {
        let gib: Int64 = 1 << 30
        #expect(MemoryText.usage(used: gib * 23 / 2, total: 16 * gib, locale: en) == "11.5 of 16 GB")
    }
}

@Suite struct PurgeResultTests {
    @Test func mapsOsascriptOutcomes() {
        #expect(PurgeResult(status: 0, errorOutput: "") == .freed)
        #expect(PurgeResult(status: 1, errorOutput: "execution error: User canceled. (-128)") == .cancelled)
        #expect(PurgeResult(status: 1, errorOutput: "execution error: purge: failed (1)") == .failed)
    }
}

@MainActor
@Suite struct PreferenceStoreTests {
    @Test func roundTripsChoicesAndHistory() throws {
        let suite = "FreeMyMacOSTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = UserDefaultsPreferenceStore(defaults: defaults)
        #expect(store.selectionChoices.isEmpty)
        #expect(store.history.isEmpty)

        let record = CleanRecord(date: Date(timeIntervalSince1970: 1_700_000_000), freedBytes: 42,
                                 targetIDs: ["xcode.derivedData"], failureCount: 1, isDryRun: false)
        store.selectionChoices = ["trash": true, "user.logs": false]
        store.history = [record]

        let reopened = UserDefaultsPreferenceStore(defaults: defaults)
        #expect(reopened.selectionChoices == ["trash": true, "user.logs": false])
        #expect(reopened.history == [record])
    }
}

/// The translation files: every language has every key, and keeps its placeholders.
@Suite struct LocalizationTests {
    private static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Support/Localization")

    private func table(_ language: String) throws -> [String: String] {
        let url = Self.folder.appendingPathComponent("\(language).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        return try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        )
    }

    private func placeholders(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?(?:@|lld|d)")
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .map { String(text[Range($0.range, in: text)!]).replacingOccurrences(of: #"\d+\$"#, with: "", options: .regularExpression) }
            .sorted()
    }

    @Test func turkishAndGermanHaveTheSameKeys() throws {
        let turkish = try table("tr")
        let german = try table("de")
        #expect(turkish.count > 100)
        #expect(Set(turkish.keys) == Set(german.keys))
    }

    @Test func translationsKeepTheirPlaceholders() throws {
        for language in ["tr", "de"] {
            for (key, value) in try table(language) {
                #expect(placeholders(key) == placeholders(value), "\(language): \(key)")
                #expect(!value.isEmpty, "\(language): \(key)")
            }
        }
    }

    @Test func everyCatalogTitleAndDetailIsTranslated() throws {
        let turkish = try table("tr")
        let targets = TargetCatalog.all(home: URL(fileURLWithPath: "/Users/test"), ownBundleID: "x")
        for target in targets {
            #expect(turkish[target.title] != nil, "\(target.title)")
            #expect(turkish[target.detail] != nil, "\(target.detail)")
        }
    }
}

@MainActor
@Suite struct RenderingTests {
    /// The whole window renders with mock data in each phase without crashing.
    @Test func rootViewRendersWithMockData() async throws {
        let targets = TargetCatalog.all(home: URL(fileURLWithPath: "/Users/test"), ownBundleID: "x")
        let model = AppModel(targets: targets, scanner: MockScanner(), cleaner: MockCleaner(),
                             store: MockData.preferences())
        func render() throws {
            let view = RootView(model: model, memory: MockData.memory)
                .frame(width: Theme.windowSize.width, height: Theme.windowSize.height)
            let image = try #require(ImageRenderer(content: view).nsImage)
            #expect(image.size.width >= Theme.windowSize.width)
        }
        try render()                 // idle
        await model.scan()
        #expect(model.phase == .ready)
        try render()                 // ready
        await model.clean()
        try render()                 // done
    }
}
