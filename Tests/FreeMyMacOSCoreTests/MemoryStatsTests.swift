import Testing
@testable import FreeMyMacOSCore

@Suite struct MemoryStatsTests {
    /// Reads system memory only; touches no files.
    @Test func currentIsSane() throws {
        let stats = try #require(MemoryStats.current())
        #expect(stats.total > 0)
        #expect(stats.used > 0)
        #expect(stats.used <= stats.total)
    }
}
