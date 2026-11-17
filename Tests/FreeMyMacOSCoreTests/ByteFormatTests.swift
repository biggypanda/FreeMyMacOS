import Foundation
import Testing
@testable import FreeMyMacOSCore

@Suite struct ByteFormatTests {
    @Test func formatsLikeFinder() {
        #expect(ByteFormat.string(1_500_000) == "1.5 MB")
        #expect(ByteFormat.string(31_100_000_000) == "31.1 GB")
    }

    @Test func zeroIsNotSpelledOut() {
        #expect(ByteFormat.string(0) == "0 bytes")
    }

    @Test func diskSpaceOfTemporaryVolume() throws {
        let space = try #require(DiskSpace.current(for: FileManager.default.temporaryDirectory))
        #expect(space.total > 0)
        #expect(space.free >= 0)
        #expect(space.free <= space.total)
    }
}
