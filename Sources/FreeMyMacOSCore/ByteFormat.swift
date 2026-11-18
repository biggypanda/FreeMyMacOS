import Foundation

/// Byte counts shown the way Finder shows them (decimal units), in the person's locale:
/// "23.94 GB" in English, "23,94 GB" in Turkish and German.
public enum ByteFormat {
    /// A formatted byte count split into its number and unit, for the hero ("23.94" over "GB").
    public struct Parts: Equatable, Sendable {
        /// The number as shown, e.g. "23,94".
        public let text: String
        /// Its value, e.g. 23.94.
        public let number: Double
        /// Digits after the decimal separator.
        public let decimals: Int
        /// e.g. "GB", "bytes", "bayt".
        public let unit: String
    }

    /// Zero reads "0 bytes", never "Zero kB".
    private static func style(_ locale: Locale) -> ByteCountFormatStyle {
        ByteCountFormatStyle(style: .file, spellsOutZero: false, locale: locale)
    }

    public static func string(_ bytes: Int64, locale: Locale = .current) -> String {
        bytes.formatted(style(locale))
    }

    /// Splits `string(bytes)` at its first space (the formatter puts the number first in
    /// every language the app ships in).
    public static func parts(_ bytes: Int64, locale: Locale = .current) -> Parts {
        let formatted = string(bytes, locale: locale)
        guard let space = formatted.firstIndex(where: \.isWhitespace) else {
            return Parts(text: formatted, number: 0, decimals: 0, unit: "")
        }
        let text = String(formatted[..<space])
        let unit = String(formatted[formatted.index(after: space)...])
        let separator = locale.decimalSeparator ?? "."
        let pieces = text.components(separatedBy: separator)
        let decimals = pieces.count > 1 ? pieces[1].count : 0
        let digits = pieces.map { $0.filter(\.isNumber) }.joined(separator: ".")
        return Parts(text: text, number: Double(digits) ?? 0, decimals: decimals, unit: unit)
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
