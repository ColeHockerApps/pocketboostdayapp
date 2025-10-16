import Combine
import Foundation

// Pocket:Boost Day
// Extensions/Date+Utils.swift
//
// Utilities for working with local day keys ("yyyy-MM-dd"),
// weekdays, ranges, and small date helpers. EN-only formatting as requested.

public enum DateUtils {

    // MARK: - Formatters

    public static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US")
        f.timeZone = .current
        f.dateFormat = "EEE, d MMM"
        return f
    }()

    public static let weekdayShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US")
        f.timeZone = .current
        f.dateFormat = "EEE"
        return f
    }()

    // MARK: - Day Key

    /// Build a stable local day key like "2025-10-15".
    public static func dayKey(from date: Date, tz: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let start = cal.startOfDay(for: date)
        return dayKeyFormatter.string(from: start)
    }

    /// Parse "yyyy-MM-dd" back into a local Date (start of that day).
    public static func date(fromDayKey key: String) -> Date? {
        dayKeyFormatter.date(from: key)
    }

    // MARK: - Ranges

    /// Returns array of last N days' keys ending at endDate (inclusive).
    public static func lastNDaysKeys(_ n: Int, endDate: Date) -> [String] {
        guard n > 0 else { return [] }
        var keys: [String] = []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let end = cal.startOfDay(for: endDate)
        for i in stride(from: n - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: end) {
                keys.append(dayKey(from: d))
            }
        }
        return keys
    }

    /// Return (startOfWeek, endOfWeek) for the week containing `date`.
    /// Start is the calendar's firstWeekday (usually Monday/Sunday), end is start + 6 days.
    public static func weekRange(containing date: Date) -> (start: Date, end: Date) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current

        let sod = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: sod)
        let shift = (weekday - cal.firstWeekday + 7) % 7
        let start = cal.date(byAdding: .day, value: -shift, to: sod) ?? sod
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? sod
        return (start, end)
    }

    // MARK: - Labels

    /// "Today" for today; otherwise a short day like "Wed, 15 Oct".
    public static func friendlyDayLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        return shortDayFormatter.string(from: date)
    }

    /// "Today" for today; otherwise the weekday short like "Mon".
    public static func weekdayShort(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        return weekdayShortFormatter.string(from: date)
    }
}

// MARK: - Calendar helpers

public extension Calendar {
    func dayKey(from date: Date) -> String {
        DateUtils.dayKey(from: date, tz: self.timeZone)
    }

    func date(fromDayKey key: String) -> Date? {
        DateUtils.date(fromDayKey: key)
    }
}

// MARK: - Date helpers

public extension Date {
    /// Local start of day.
    var startOfDayLocal: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// True if both dates fall on the same local day.
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// Add a number of whole days (local).
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Day key string "yyyy-MM-dd".
    var dayKey: String {
        DateUtils.dayKey(from: self)
    }

    /// Short weekday label, e.g., "Mon".
    var weekdayShort: String {
        DateUtils.weekdayShort(for: self)
    }

    /// Friendly "Today" or "Wed, 15 Oct".
    var friendlyDayLabel: String {
        DateUtils.friendlyDayLabel(for: self)
    }
}
