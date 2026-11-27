import Foundation

// "What if I spend $200 on Wednesday?": read the question, then compare the forecast with and without it.
// Nothing here changes the ledger; saving the purchase as a planned expense is a separate, explicit step.

/// An amount and the day it would go out, read from something like "$200 on Wednesday for shoes".
public struct PurchaseIdea: Equatable, Sendable {
    public var cents: Cents
    public var day: Day
    /// Words after "for", when there are any.
    public var label: String?

    public init(cents: Cents, day: Day, label: String? = nil) {
        self.cents = cents
        self.day = day
        self.label = label
    }
}

public enum PurchaseParseError: Error, Equatable, Sendable {
    case noAmount
    case unknownDay(String)
    case pastDay
    case tooFar
}

public enum PurchaseParser {
    /// Furthest day a purchase can be checked, matching the longest Plan range.
    public static let maxDays = 365

    /// Reads "$200 on Wednesday", "45.50 tomorrow", "1,200 on Dec 3 for a laptop", "80 in 2 weeks".
    /// A missing day means today. `dayFirst` reads "3/12" as 3 December instead of March 12.
    public static func parse(_ text: String, today: Day, dayFirst: Bool = false) -> Result<PurchaseIdea, PurchaseParseError> {
        var source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var label: String?
        if let r = source.range(of: #"(^|\s)for\s"#, options: [.regularExpression, .caseInsensitive]) {
            let name = source[r.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            label = name.isEmpty ? nil : name
            source = String(source[..<r.lowerBound])
        }
        let s = source.lowercased().replacingOccurrences(of: "’", with: "'")
        var tokens = s.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        // "$ 200" → "$200"
        var i = 0
        while i < tokens.count - 1 {
            if tokens[i].unicodeScalars.allSatisfy({ $0.properties.generalCategory == .currencySymbol }) {
                tokens[i] += tokens.remove(at: i + 1)
            }
            i += 1
        }
        tokens.removeAll { ["dollars", "dollar", "bucks", "usd", "eur", "euros", "gbp", "pounds"].contains($0) }

        func hasSymbol(_ t: String) -> Bool { t.unicodeScalars.contains { $0.properties.generalCategory == .currencySymbol } }
        let amountIndex = tokens.firstIndex { hasSymbol($0) && Money.parse($0) != nil }
            ?? tokens.firstIndex { Money.parse($0) != nil }
        guard let amountIndex, let cents = Money.parse(tokens[amountIndex]) else { return .failure(.noAmount) }
        tokens.remove(at: amountIndex)

        let filler: Set<String> = ["on", "this", "coming", "at", "the", "by", "spend", "spending", "buy", "buying"]
        let phrase = tokens.filter { !filler.contains($0) }
        guard let day = resolve(phrase, today: today, dayFirst: dayFirst) else {
            return .failure(.unknownDay(tokens.joined(separator: " ")))
        }
        if day < today { return .failure(.pastDay) }
        if today.days(until: day) > maxDays { return .failure(.tooFar) }
        return .success(PurchaseIdea(cents: cents, day: day, label: label))
    }

    private static let weekdays: [(names: [String], weekday: Int)] = [
        (["sunday", "sun"], 1), (["monday", "mon"], 2), (["tuesday", "tue", "tues"], 3),
        (["wednesday", "wed", "weds"], 4), (["thursday", "thu", "thur", "thurs"], 5),
        (["friday", "fri"], 6), (["saturday", "sat"], 7),
    ]

    private static let months: [String: Int] = {
        var out: [String: Int] = [:]
        let names = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
        for (i, name) in names.enumerated() {
            out[name] = i + 1
            out[String(name.prefix(3))] = i + 1
        }
        out["sept"] = 9
        return out
    }()

    private static func ordinal(_ t: String) -> Int? {
        var s = t
        for suffix in ["st", "nd", "rd", "th"] where s.hasSuffix(suffix) { s.removeLast(2) }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: ","))
        guard let n = Int(s), (1...31).contains(n) else { return nil }
        return n
    }

    static func resolve(_ words: [String], today: Day, dayFirst: Bool) -> Day? {
        var w = words.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ",.")) }.filter { !$0.isEmpty }
        if w.isEmpty || w == ["today"] || w == ["now"] || w == ["tonight"] { return today }
        if ["tomorrow", "tmrw", "tmr", "tomorow"].contains(w.joined()) { return today.adding(days: 1) }
        if w == ["next", "week"] { return today.adding(days: 7) }
        if w == ["next", "month"] { return today.adding(months: 1) }

        // "in 3 days", "in a week", "in 2 weeks", "in a month"
        if w.first == "in", w.count == 3, let unit = w.last {
            let n = w[1] == "a" || w[1] == "an" || w[1] == "one" ? 1 : Int(w[1])
            if let n, n >= 0 {
                if unit.hasPrefix("day") { return today.adding(days: n) }
                if unit.hasPrefix("week") { return today.adding(days: 7 * n) }
                if unit.hasPrefix("month") { return today.adding(months: n) }
            }
        }

        // "wednesday", "next wed": the next one, today included unless "next" was said.
        var strictlyAfter = false
        if w.first == "next" { strictlyAfter = true; w.removeFirst() }
        if w.count == 1, let match = weekdays.first(where: { $0.names.contains(w[0]) }) {
            let current = Day.utc.component(.weekday, from: today.anchorDate)
            var ahead = (match.weekday - current + 7) % 7
            if ahead == 0 && strictlyAfter { ahead = 7 }
            return today.adding(days: ahead)
        }
        if strictlyAfter { return nil }

        // "2026-12-03"
        if w.count == 1, let iso = Day(iso: w[0]) { return iso }

        // "12/3", "12/3/26", "3.12.2026"
        if w.count == 1, let parts = numericDate(w[0]) {
            let (a, b, year) = parts
            let (m, d) = dayFirst ? (b, a) : (a, b)
            return day(year: year, month: m, day: d, today: today)
        }

        // "dec 3", "december 3rd", "3 dec", "dec 3 2026"
        if (2...3).contains(w.count) {
            var year: Int?
            if w.count == 3 {
                guard let y = Int(w[2]), (2000...2100).contains(y) else { return nil }
                year = y
            }
            if let m = months[w[0]], let d = ordinal(w[1]) { return day(year: year, month: m, day: d, today: today) }
            if let d = ordinal(w[0]), let m = months[w[1]] { return day(year: year, month: m, day: d, today: today) }
            return nil
        }

        // "the 15th": this month, or next month once it's passed.
        if w.count == 1, w[0].range(of: #"^\d{1,2}(st|nd|rd|th)$"#, options: .regularExpression) != nil, let d = ordinal(w[0]) {
            var month = today.yearMonth
            for _ in 0..<2 {
                if let candidate = Day(iso: String(format: "%04d-%02d-%02d", month.year, month.month, d)), candidate >= today {
                    return candidate
                }
                month = month.adding(1)
            }
        }
        return nil
    }

    private static func numericDate(_ t: String) -> (Int, Int, Int?)? {
        let parts = t.split(whereSeparator: { $0 == "/" || $0 == "." || $0 == "-" }).map(String.init)
        guard (2...3).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let a = Int(parts[0]), let b = Int(parts[1]), parts[0].count <= 2, parts[1].count <= 2 else { return nil }
        var year: Int?
        if parts.count == 3, let y = Int(parts[2]) { year = parts[2].count == 2 ? 2000 + y : y }
        return (a, b, year)
    }

    private static func day(year: Int?, month: Int, day: Int, today: Day) -> Day? {
        if let year { return Day(iso: String(format: "%04d-%02d-%02d", year, month, day)) }
        guard let thisYear = Day(iso: String(format: "%04d-%02d-%02d", today.year, month, day)) else {
            return Day(iso: String(format: "%04d-%02d-%02d", today.year + 1, month, day))
        }
        return thisYear >= today ? thisYear : Day(iso: String(format: "%04d-%02d-%02d", today.year + 1, month, day))
    }
}

/// The forecast with and without a purchase someone is considering.
public struct PurchaseCheck: Sendable {
    public var idea: PurchaseIdea
    public var before: Projection
    public var after: Projection
    /// Set when a payday is chosen and the purchase lands before it.
    public var paydayBefore: Projection?
    public var paydayAfter: Projection?

    /// The new lowest point is lower than it would have been, or the purchase creates one.
    public var lowersLowPoint: Bool { after.lowBalance < before.lowBalance }
    /// The purchase is what takes the balance below zero in this range.
    public var causesShortfall: Bool { before.hitZero == nil && after.hitZero != nil && before.start >= 0 }
}

extension Ledger {
    /// A copy with the purchase as a one-time planned expense, the same shape "Save as Planned Expense" adds.
    public func withPlannedPurchase(_ idea: PurchaseIdea, label: String) -> Ledger {
        var copy = self
        copy.rules.append(Rule(cents: -idea.cents, label: label, cadence: .monthly, anchor: idea.day, total: 1, auto: true))
        return copy
    }

    /// Compares the forecast over `days` (stretched to cover two weeks past the purchase) and, when a payday is
    /// chosen after the purchase, what's available until payday.
    public func checkPurchase(_ idea: PurchaseIdea, today: Day, days: Int, everyday: Cents,
                              payday: Day? = nil, paydayEveryday: Cents = 0) -> PurchaseCheck {
        let span = max(days, today.days(until: idea.day) + 14)
        let trial = withPlannedPurchase(idea, label: idea.label ?? "Purchase")
        var check = PurchaseCheck(idea: idea,
                                  before: project(today: today, days: span, everyday: everyday),
                                  after: trial.project(today: today, days: span, everyday: everyday))
        if let payday, idea.day < payday {
            check.paydayBefore = projectBeforePayday(today: today, payday: payday, everyday: paydayEveryday)
            check.paydayAfter = trial.projectBeforePayday(today: today, payday: payday, everyday: paydayEveryday)
        }
        return check
    }
}
