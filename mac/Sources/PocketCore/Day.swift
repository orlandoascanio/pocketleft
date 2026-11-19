import Foundation

/// A calendar day with no time or time zone, stored as "yyyy-MM-dd".
/// Money moves on days, so this avoids every midnight / time-zone surprise.
public struct Day: Hashable, Comparable, Codable, CustomStringConvertible, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Fixed calendar for arithmetic, so results never depend on the machine's time zone.
    static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar` (the user's own calendar by default).
    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    public init?(iso: String) {
        let components = iso.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count == 3, components.map(\.count) == [4, 2, 2],
              components.allSatisfy({ $0.allSatisfy { "0123456789".contains($0) } }) else { return nil }
        let parts = components.compactMap { Int($0) }
        guard parts.count == 3, (1...9999).contains(parts[0]), (1...12).contains(parts[1]),
              (1...31).contains(parts[2]),
              let date = Day.utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              Day.utc.component(.month, from: date) == parts[1],
              Day.utc.component(.day, from: date) == parts[2] else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public static var today: Day { Day(Date()) }

    public var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }
    public var description: String { iso }

    /// Noon UTC on this day: safe for arithmetic.
    var anchorDate: Date { Day.utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))! }

    /// Noon on this day in the user's calendar: use for display and for DatePicker.
    public var localDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    public func adding(days n: Int) -> Day { adding(.day, n) }
    public func adding(months n: Int) -> Day { adding(.month, n) }
    public func adding(years n: Int) -> Day { adding(.year, n) }

    /// Month and year math clamps to the month's end (Jan 31 + 1 month = Feb 28).
    private func adding(_ unit: Calendar.Component, _ n: Int) -> Day {
        Day(Day.utc.date(byAdding: unit, value: n, to: anchorDate)!, calendar: Day.utc)
    }

    public func days(until other: Day) -> Int {
        Day.utc.dateComponents([.day], from: anchorDate, to: other.anchorDate).day ?? 0
    }

    public var yearMonth: YearMonth { YearMonth(year: year, month: month) }

    public static func < (a: Day, b: Day) -> Bool { (a.year, a.month, a.day) < (b.year, b.month, b.day) }

    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let d = Day(iso: s) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad day \(s)"))
        }
        self = d
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(iso)
    }
}

public struct YearMonth: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public var first: Day { Day(year: year, month: month, day: 1) }
    public var last: Day { adding(1).first.adding(days: -1) }
    public func adding(_ n: Int) -> YearMonth { first.adding(months: n).yearMonth }
    public func contains(_ d: Day) -> Bool { d.year == year && d.month == month }

    public static func < (a: YearMonth, b: YearMonth) -> Bool { (a.year, a.month) < (b.year, b.month) }
}
