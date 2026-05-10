import Foundation

extension Date {
    func formatted(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.locale = Locale(identifier: "fr_BE")
        return formatter.string(from: self)
    }

    func formatted(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.locale = Locale(identifier: "fr_BE")
        return formatter.string(from: self)
    }

    var shortDate: String { formatted(style: .short) }
    var mediumDate: String { formatted(style: .medium) }
    var longDate: String { formatted(style: .long) }
}

extension String {
    /// Parses a Laravel-formatted date string (`Y-m-d`, `Y-m-d H:i:s`, ISO 8601) into a `Date`.
    /// Returns `nil` if no known format matches. Used by Views that receive raw String dates from API models.
    func toDate() -> Date? {
        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoWithFraction.date(from: self) { return d }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: self) { return d }

        let dt = DateFormatter()
        dt.locale = Locale(identifier: "en_US_POSIX")
        dt.timeZone = TimeZone(identifier: "UTC")
        dt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = dt.date(from: self) { return d }

        let dateOnly = DateFormatter()
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.timeZone = TimeZone(identifier: "UTC")
        dateOnly.dateFormat = "yyyy-MM-dd"
        return dateOnly.date(from: self)
    }
}
