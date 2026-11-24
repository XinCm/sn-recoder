import Foundation

/// One month laid out on a Monday-first, seven-column grid.
struct MonthGrid: Equatable {
    struct Day: Identifiable, Equatable {
        let key: String
        let day: Int

        var id: String { key }
    }

    let monthStart: Date
    let year: Int
    let month: Int
    let leadingBlanks: Int
    let days: [Day]
    let rowCount: Int

    init(containing date: Date, calendar: Calendar = DateKey.calendar) {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 1
        let month = components.month ?? 1
        let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? date
        let dayRange = calendar.range(of: .day, in: .month, for: start) ?? 1..<2

        self.monthStart = calendar.startOfDay(for: start)
        self.year = year
        self.month = month
        self.leadingBlanks = CalendarText.weekdayIndex(for: start, calendar: calendar)

        var days: [Day] = []
        days.reserveCapacity(dayRange.count)
        for day in dayRange {
            let key = String(format: DateKey.keyFormat, year, month, day)
            days.append(Day(key: key, day: day))
        }
        self.days = days
        self.rowCount = max(1, Int(ceil(Double(leadingBlanks + days.count) / 7.0)))
    }

    var title: String {
        CalendarText.monthTitle(year: year, month: month)
    }

    var monthPrefix: String {
        String(format: "%04d-%02d", year, month)
    }

    /// nil means a blank slot before the first day or after the last day.
    func day(at index: Int) -> Day? {
        let dayIndex = index - leadingBlanks
        guard dayIndex >= 0, dayIndex < days.count else { return nil }
        return days[dayIndex]
    }

    static func monthStart(containing date: Date, calendar: Calendar = DateKey.calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1)) ?? date
    }

    static func shifting(months delta: Int, from date: Date, calendar: Calendar = DateKey.calendar) -> Date {
        let start = monthStart(containing: date, calendar: calendar)
        guard let shifted = calendar.date(byAdding: .month, value: delta, to: start) else { return start }
        return monthStart(containing: shifted, calendar: calendar)
    }
}
