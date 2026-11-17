import Foundation

/// Byte counts shown the way Finder shows them (decimal units).
public enum ByteFormat {
    /// Zero reads "0 bytes", never "Zero kB".
    private static let style = ByteCountFormatStyle(
        style: .file, spellsOutZero: false, locale: Locale(identifier: "en_US")
    )

    public static func string(_ bytes: Int64) -> String {
        bytes.formatted(style)
    }
}

/// Capacity of the volume that holds a given URL.
public struct DiskSpace: Sendable, Equatable {
    public let total: Int64
    /// Space available for important usage (what Finder shows), including purgeable space.
    public let free: Int64

    public init(total: Int64, free: Int64) {
        self.total = total
        self.free = free
    }

    public static func current(for url: URL) -> DiskSpace? {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity
        else { return nil }
        let free = values.volumeAvailableCapacityForImportantUsage
            ?? values.volumeAvailableCapacity.map(Int64.init)
            ?? 0
        return DiskSpace(total: Int64(total), free: min(max(free, 0), Int64(total)))
    }
}
