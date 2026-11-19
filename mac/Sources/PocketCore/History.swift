import Foundation

/// What History shows: words to look for, money in or out, a category and a date range.
public struct EntryQuery: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Identifiable, Sendable {
        case all, spending, income
        public var id: String { rawValue }
        public var name: String {
            switch self {
            case .all: "In and out"
            case .spending: "Spending"
            case .income: "Money in"
            }
        }
    }

    /// Quick date ranges, counted from today.
    public enum Period: String, CaseIterable, Identifiable, Sendable {
        case thisMonth, lastMonth, last3Months, thisYear
        public var id: String { rawValue }
        public var name: String {
            switch self {
            case .thisMonth: "This month"
            case .lastMonth: "Last month"
            case .last3Months: "Last 3 months"
            case .thisYear: "This year"
            }
        }

        public func range(today: Day) -> (from: Day, to: Day) {
            switch self {
            case .thisMonth: (today.yearMonth.first, today)
            case .lastMonth: (today.yearMonth.adding(-1).first, today.yearMonth.first.adding(days: -1))
            case .last3Months: (today.yearMonth.adding(-2).first, today)
            case .thisYear: (Day(year: today.year, month: 1, day: 1), today)
            }
        }
    }

    public var text: String
    public var kind: Kind
    /// A category key, including `Categories.uncategorized` for entries with no category.
    public var category: String?
    public var from: Day?
    public var to: Day?

    public init(text: String = "", kind: Kind = .all, category: String? = nil, from: Day? = nil, to: Day? = nil) {
        self.text = text
        self.kind = kind
        self.category = category
        self.from = from
        self.to = to
    }

    /// Everything in one month (what Insights links to).
    public init(category: String?, month: YearMonth?) {
        self.init(category: category, from: month?.first, to: month?.last)
    }

    public var isEmpty: Bool { words.isEmpty && kind == .all && category == nil && from == nil && to == nil }

    /// The quick range this matches exactly, if any.
    public func period(today: Day) -> Period? {
        Period.allCases.first { let r = $0.range(today: today); return r.from == from && r.to == to }
    }

    /// The single month this covers exactly, if any.
    public var month: YearMonth? {
        guard let from, let to, from.day == 1, to == from.yearMonth.adding(1).first.adding(days: -1) else { return nil }
        return from.yearMonth
    }

    private var words: [String] { Self.fold(text).split(whereSeparator: \.isWhitespace).map(String.init) }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Every word has to appear in the label, the category's name or the amount ("9.99").
    public func matches(_ e: Entry) -> Bool {
        if let from, e.day < from { return false }
        if let to, e.day > to { return false }
        switch kind {
        case .all: break
        case .spending: if e.cents > 0 || e.category == Categories.start { return false }
        case .income: if e.cents <= 0 || e.category == Categories.start { return false }
        }
        if let category, Categories.key(e.category) != category { return false }
        let words = words
        guard !words.isEmpty else { return true }
        let haystack = Self.fold([e.label, e.category == nil ? "" : Categories.name(e.category), Money.edit(e.cents)].joined(separator: " "))
        return words.allSatisfy { haystack.contains($0) }
    }
}

extension Ledger {
    /// History that matches, newest first.
    public func search(_ query: EntryQuery) -> [Entry] { sortedEntries.filter(query.matches) }
}

/// Entries as a spreadsheet file.
public enum CSV {
    /// Oldest first, one row per entry. Amounts are plain numbers (negative = spent) so spreadsheets can add them up.
    public static func entries(_ entries: [Entry], currency: String) -> String {
        var rows = ["Date,Description,Category,Amount,Currency,Type,Scheduled"]
        for e in entries.sorted(by: { ($0.day, $0.created) < ($1.day, $1.created) }) {
            let type = e.category == Categories.start ? "Starting balance" : e.cents < 0 ? "Spent" : "Money in"
            rows.append([e.day.iso, text(e.label), text(e.category == nil ? "" : Categories.name(e.category)),
                         amount(e.cents), currency, type, e.ruleID == nil ? "No" : "Yes"].joined(separator: ","))
        }
        // The byte order mark tells Excel the file is UTF-8, so names with accents open correctly.
        return "\u{FEFF}" + rows.joined(separator: "\r\n") + "\r\n"
    }

    static func amount(_ cents: Cents) -> String {
        (cents < 0 ? "-" : "") + "\(abs(cents) / 100)." + String(format: "%02d", abs(cents) % 100)
    }

    /// Quotes a value when it needs it, and keeps spreadsheets from running text as a formula.
    static func text(_ value: String) -> String {
        var s = value
        if let first = s.first, "=+-@\t\r".contains(first) { s = "'" + s }
        guard s.contains(where: { ",\"\n\r".contains($0) }) else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
