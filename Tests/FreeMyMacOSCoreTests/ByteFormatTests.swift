import Foundation
import Testing
@testable import FreeMyMacOSCore

private let en = Locale(identifier: "en_US")
private let tr = Locale(identifier: "tr_TR")
private let de = Locale(identifier: "de_DE")

@Suite struct ByteFormatTests {
    @Test func formatsLikeFinder() {
        #expect(ByteFormat.string(1_500_000, locale: en) == "1.5 MB")
        #expect(ByteFormat.string(31_100_000_000, locale: en) == "31.1 GB")
    }

    @Test func zeroIsNotSpelledOut() {
        #expect(ByteFormat.string(0, locale: en) == "0 bytes")
    }

    @Test func partsInEnglish() {
        #expect(ByteFormat.parts(23_940_000_000, locale: en)
                == .init(text: "23.94", number: 23.94, decimals: 2, unit: "GB"))
        #expect(ByteFormat.parts(917_000_000, locale: en)
                == .init(text: "917", number: 917, decimals: 0, unit: "MB"))
        #expect(ByteFormat.parts(512, locale: en).unit == "bytes")
    }

    @Test func partsUseTheLocalesDecimalComma() {
        for locale in [tr, de] {
            let parts = ByteFormat.parts(23_940_000_000, locale: locale)
            #expect(parts.text == "23,94")
            #expect(parts.number == 23.94)
            #expect(parts.decimals == 2)
            #expect(parts.unit == "GB")
        }
        #expect(ByteFormat.parts(1_400_000_000, locale: tr).number == 1.4)
    }

    @Test func partsJoinBackIntoTheString() {
        for locale in [en, tr, de] {
            for bytes: Int64 in [0, 512, 9_000, 917_000_000, 8_134_000_000] {
                let parts = ByteFormat.parts(bytes, locale: locale)
                let joined = ByteFormat.string(bytes, locale: locale)
                #expect(joined.hasPrefix(parts.text) && joined.hasSuffix(parts.unit))
            }
        }
    }

    @Test func diskSpaceOfTemporaryVolume() throws {
        let space = try #require(DiskSpace.current(for: FileManager.default.temporaryDirectory))
        #expect(space.total > 0)
        #expect(space.free >= 0)
        #expect(space.free <= space.total)
    }
}
