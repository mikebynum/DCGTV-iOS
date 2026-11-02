import Foundation

// Shared by every model whose API dates may or may not include fractional
// seconds, so each only needs to call one place instead of repeating the
// fallback logic.
enum DCGDateParsing {
    static func flexibleISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()

        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        if let date = formatter.date(from: string) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
