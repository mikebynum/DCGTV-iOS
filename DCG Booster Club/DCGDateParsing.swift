import Foundation

// The app's default MainActor isolation serializes access to the formatters.
// Reuse both formatter configurations and parsed values: schedule sorting,
// filtering and broadcast matching ask for the same dates many times per render.
enum DCGDateParsing {
    private final class ParsedDate: NSObject {
        let value: Date?
        init(_ value: Date?) { self.value = value }
    }

    private static let cache: NSCache<NSString, ParsedDate> = {
        let cache = NSCache<NSString, ParsedDate>()
        cache.countLimit = 2_048
        return cache
    }()

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func flexibleISO8601(_ string: String) -> Date? {
        let key = string as NSString
        if let cached = cache.object(forKey: key) {
            return cached.value
        }

        let date = fractionalFormatter.date(from: string) ?? standardFormatter.date(from: string)
        // Cache invalid dates too, so undated events remain inexpensive to render.
        cache.setObject(ParsedDate(date), forKey: key)
        return date
    }
}
