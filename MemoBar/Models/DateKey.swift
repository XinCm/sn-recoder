import Foundation

/// Date keys are calendar dates (`yyyy-MM-dd`) in the user's current time zone.
/// They are deliberately *not* timestamps: a memo should never drift to another
/// day just because the machine's time zone changed.
enum DateKey {
    static let keyFormat = "%04d-%02d-%02d"

    /// A Gregorian calendar with Monday as the first weekday. Rebuilt on demand
    /// so a time-zone change is picked up immediately.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone.current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    static func key(for date: Date, calendar: Calendar = DateKey.calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: keyFormat,
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func date(for key: String, calendar: Calendar = DateKey.calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func todayKey(now: Date = Date()) -> String {
        key(for: now)
    }

    static func isPast(_ key: String, todayKey: String) -> Bool {
        key < todayKey
    }

    static func isFuture(_ key: String, todayKey: String) -> Bool {
        key > todayKey
    }
}

enum CalendarText {
    static let weekdayShort = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let weekdayLong = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]

    /// 0 = Monday ... 6 = Sunday.
    static func weekdayIndex(for date: Date, calendar: Calendar = DateKey.calendar) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    static func dayTitle(for key: String) -> String {
        guard let date = DateKey.date(for: key) else { return key }
        let calendar = DateKey.calendar
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month) 月 \(day) 日"
    }

    static func weekdayLong(for key: String) -> String {
        guard let date = DateKey.date(for: key) else { return "" }
        return weekdayLong[weekdayIndex(for: date)]
    }

    static func monthTitle(year: Int, month: Int) -> String {
        "\(year) 年 \(month) 月"
    }
}
