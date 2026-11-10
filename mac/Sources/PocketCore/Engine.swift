import Foundation

// The money logic. Every function is pure over `Ledger`, so it's easy to test.

extension Ledger {
    public var balance: Cents { entries.reduce(0) { $0 + $1.cents } }

    /// Newest first (by day, then by when it was entered).
    public var sortedEntries: [Entry] {
        entries.sorted { ($0.day, $0.created) > ($1.day, $1.created) }
    }

    /// The month of the oldest entry (where Insights starts).
    public var firstMonth: YearMonth { entries.map(\.day).min()?.yearMonth ?? Day.today.yearMonth }

    // MARK: entries

    public mutating func add(_ e: Entry) { entries.append(e) }

    public mutating func update(_ e: Entry) {
        guard let i = entries.firstIndex(where: { $0.id == e.id }) else { return }
        entries[i] = e
    }

    public mutating func removeEntry(_ id: UUID) { entries.removeAll { $0.id == id } }

    // MARK: repeating money

    /// Logs every automatic payment that is due on or before `today`. Returns what it logged.
    @discardableResult
    public mutating func postDue(today: Day) -> [Entry] {
        var logged: [Entry] = []
        for i in rules.indices where rules[i].active && rules[i].auto {
            var guardCount = 0
            while !rules[i].finished, rules[i].next <= today, guardCount < 400 {
                let r = rules[i]
                let e = Entry(cents: r.cents, label: r.label, day: r.next, category: r.category, ruleID: r.id)
                entries.append(e)
                logged.append(e)
                rules[i].posted += 1
                guardCount += 1
            }
        }
        return logged
    }

    public mutating func addRule(_ r: Rule, today: Day) {
        rules.append(r)
        postDue(today: today)
    }

    /// Edit a rule. Changing how often or the next date restarts the schedule from `next`;
    /// `left` counts the payments still to come, including the next one (nil = no end).
    public mutating func updateRule(_ id: UUID, cents: Cents, label: String, cadence: Cadence, next: Day,
                                    left: Int?, category: String?, auto: Bool, today: Day, subscription: Bool? = nil, once: Bool? = nil) {
        guard let i = rules.firstIndex(where: { $0.id == id }) else { return }
        if cadence != rules[i].cadence || next != rules[i].next {
            rules[i].anchor = next
            rules[i].posted = 0
            rules[i].cadence = cadence
            rules[i].total = left
        } else {
            rules[i].total = left.map { rules[i].posted + $0 }
        }
        rules[i].cents = cents
        rules[i].label = label
        rules[i].category = category
        rules[i].auto = auto
        if let subscription { rules[i].subscription = subscription }
        if let once { rules[i].once = once }
        postDue(today: today)
    }

    /// Stops a rule. Payments already logged stay in history.
    public mutating func removeRule(_ id: UUID) {
        rules.removeAll { $0.id == id }
        for i in entries.indices where entries[i].ruleID == id { entries[i].ruleID = nil }
    }

    /// "Got it": log the next payment now with the real amount and date (early, late, or different).
    @discardableResult
    public mutating func settle(_ id: UUID, cents: Cents? = nil, on day: Day, today: Day) -> Entry? {
        guard let i = rules.firstIndex(where: { $0.id == id }), !rules[i].finished else { return nil }
        let r = rules[i]
        let e = Entry(cents: cents ?? r.cents, label: r.label, day: day, category: r.category, ruleID: r.id)
        entries.append(e)
        rules[i].posted += 1
        postDue(today: today)
        return e
    }

    /// "Skip this one": the next payment won't happen.
    public mutating func skip(_ id: UUID) {
        guard let i = rules.firstIndex(where: { $0.id == id }), !rules[i].finished else { return }
        rules[i].posted += 1
    }

    /// Pause or resume. Resuming doesn't back-log what was missed while paused.
    public mutating func setActive(_ id: UUID, _ active: Bool, today: Day) {
        guard let i = rules.firstIndex(where: { $0.id == id }) else { return }
        if active && !rules[i].active {
            var guardCount = 0
            while !rules[i].finished, rules[i].next < today, guardCount < 400 {
                rules[i].posted += 1
                guardCount += 1
            }
        }
        rules[i].active = active
        postDue(today: today)
    }

    /// Rules still going (finished ones drop out), active first, soonest first.
    public var liveRules: [Rule] {
        rules.filter { !$0.finished }.sorted { ($0.active ? 0 : 1, $0.next, $0.label) < ($1.active ? 0 : 1, $1.next, $1.label) }
    }

    /// Every active payment from now until `today + days`, including overdue ones still waiting.
    public func upcoming(today: Day, days: Int) -> [Occurrence] {
        let horizon = today.adding(days: days)
        var out: [Occurrence] = []
        for r in rules where r.active && !r.finished {
            for g in 0..<400 {
                if let t = r.total, r.posted + g >= t { break }
                let d = r.occurrence(r.posted + g)
                if d > horizon { break }
                out.append(Occurrence(ruleID: r.id, label: r.label, cents: r.cents, category: r.category,
                                      day: d, overdue: d <= today, isNext: g == 0))
            }
        }
        return out.sorted { ($0.day, $0.label) < ($1.day, $1.label) }
    }

    /// Money that was due but hasn't been confirmed (the next one per rule).
    public func waiting(today: Day) -> [Occurrence] {
        upcoming(today: today, days: 0).filter { $0.overdue && $0.isNext }
    }

    // MARK: forecast

    /// What you usually spend on things nobody scheduled (food, shopping, games…), so the forecast isn't only bills.
    /// It's the median of the last full weeks (up to `maxWeeks`, ending yesterday), so one big purchase doesn't
    /// skew it. Needs two full weeks since the first entry; nil until then, or when nothing unscheduled was spent.
    public func everydaySpending(today: Day, maxWeeks: Int = 12) -> EverydaySpending? {
        guard let first = entries.map(\.day).min() else { return nil }
        let weeks = min(maxWeeks, first.days(until: today) / 7)
        guard weeks >= 2 else { return nil }
        let start = today.adding(days: -7 * weeks)
        var totals = Array(repeating: 0, count: weeks)
        for e in entries where e.cents < 0 && e.ruleID == nil && e.category != Categories.start && e.day >= start && e.day < today {
            totals[(e.day.days(until: today) - 1) / 7] -= e.cents
        }
        let sorted = totals.sorted()
        let mid = sorted.count / 2
        let median = sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
        guard median > 0 else { return nil }
        return EverydaySpending(weekly: median, weeks: weeks)
    }

    /// The balance from today to `today + days`: scheduled payments land on their day, and `everyday` (cents a day)
    /// goes out every day after today.
    public func project(today: Day, days: Int, everyday: Cents = 0) -> Projection {
        let end = today.adding(days: days)
        let events = upcoming(today: today, days: days)
            .map { o -> Occurrence in var o = o; if o.overdue { o.day = today }; return o }
            .sorted { ($0.day, $0.label) < ($1.day, $1.label) }
        let start = balance
        var bal = start
        var spentThrough = today
        var points = [Projection.Point(day: today, before: start, balance: start, events: [])]
        var steps: [Projection.Step] = []
        var hitZero: Day?
        var backAbove: Occurrence?
        var low = (day: today, balance: start)
        // Everyday spending up to `day`, noting the day it first takes the balance below zero.
        func spend(through day: Day) {
            guard day > spentThrough else { return }
            if everyday > 0 {
                let after = bal - everyday * spentThrough.days(until: day)
                if bal >= 0 && after < 0 && hitZero == nil { hitZero = spentThrough.adding(days: bal / everyday + 1) }
                bal = after
                if bal < low.balance { low = (day, bal) }
            }
            spentThrough = day
        }
        for e in events {
            spend(through: e.day)
            let before = bal
            bal += e.cents
            steps.append(.init(occurrence: e, after: bal))
            if points.count > 1, points[points.count - 1].day == e.day {
                points[points.count - 1].balance = bal
                points[points.count - 1].events.append(e)
            } else {
                points.append(.init(day: e.day, before: before, balance: bal, events: [e]))
            }
            if before >= 0 && bal < 0 && hitZero == nil { hitZero = e.day }
            if before < 0 && bal >= 0 && backAbove == nil { backAbove = e }
            if bal < low.balance { low = (e.day, bal) }
        }
        spend(through: end)
        return Projection(today: today, end: end, days: days, everyday: everyday, start: start, endBalance: bal, points: points,
                          steps: steps, hitZero: hitZero, backAbove: backAbove, lowDay: low.day, lowBalance: low.balance)
    }

    /// Roughly how many months the balance lasts at the usual pace: `everyday` spending plus repeating money
    /// averaged per month. nil when nothing is left, or when money isn't going down at that pace.
    public func monthsLeft(everyday: Cents) -> Double? {
        Ledger.monthsLeft(balance: balance, everyday: everyday,
                          repeating: rules.filter { $0.active && !$0.finished && !$0.isOnce }.map { ($0.cents, $0.cadence) })
    }

    public static func monthsLeft(balance: Cents, everyday: Cents, repeating: [(Cents, Cadence)]) -> Double? {
        guard balance > 0 else { return nil }
        let monthly = Double(everyday) * 365.25 / 12 - repeating.reduce(0) { $0 + Double($1.0) * $1.1.perMonth }
        guard monthly > 0 else { return nil }
        return Double(balance) / monthly
    }

    // MARK: insights

    /// Spending and money in for a month (or all time when nil). The starting balance isn't income.
    public func summary(_ month: YearMonth?) -> Summary {
        var spent: Cents = 0
        var income: Cents = 0
        var out: [String: (Cents, Int)] = [:]
        var into: [String: (Cents, Int)] = [:]
        for e in entries where e.category != Categories.start && (month?.contains(e.day) ?? true) {
            let c = Categories.key(e.category, cents: e.cents)
            if e.cents > 0 {
                income += e.cents
                let cur = into[c] ?? (0, 0)
                into[c] = (cur.0 + e.cents, cur.1 + 1)
            } else {
                spent -= e.cents
                let cur = out[c] ?? (0, 0)
                out[c] = (cur.0 - e.cents, cur.1 + 1)
            }
        }
        func rows(_ by: [String: (Cents, Int)]) -> [CategoryTotal] {
            by.map { CategoryTotal(category: $0.key, cents: $0.value.0, count: $0.value.1) }
                .sorted { ($0.cents, $1.category) > ($1.cents, $0.category) }
        }
        return Summary(spent: spent, income: income, byCategory: rows(out), incomeByCategory: rows(into))
    }

    /// The category most often used with labels starting like `prefix` (so "valo" picks Games).
    public func guessCategory(for prefix: String, income: Bool) -> String? {
        let q = prefix.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 3 else { return nil }
        let allowed = Set((income ? Categories.income : Categories.spending).map(\.id))
        let fromPresets = presets.first { ($0.category.map(allowed.contains) ?? false) && $0.label.lowercased().hasPrefix(q) }
        if let c = fromPresets?.category { return c }
        return sortedEntries.first { ($0.category.map(allowed.contains) ?? false) && $0.label.lowercased().hasPrefix(q) }?.category
    }
}

public struct Projection: Sendable {
    public struct Point: Identifiable, Sendable {
        public var day: Day
        /// Just before this day's payments land (after everyday spending).
        public var before: Cents
        public var balance: Cents
        public var events: [Occurrence]
        public var id: String { day.iso + "\(events.count)" }
    }

    public struct Step: Identifiable, Sendable {
        public var occurrence: Occurrence
        public var after: Cents
        public var id: String { occurrence.id }
    }

    public var today: Day
    public var end: Day
    public var days: Int
    /// Everyday spending counted in, in cents a day (0 = scheduled payments only).
    public var everyday: Cents
    public var start: Cents
    public var endBalance: Cents
    public var points: [Point]
    public var steps: [Step]
    public var hitZero: Day?
    public var backAbove: Occurrence?
    public var lowDay: Day
    public var lowBalance: Cents

    public enum Runway: Equatable, Sendable {
        case backAboveOnce(String)
        case backAboveOn(Day)
        case belowForWholeRange
        case runsOut(Day)
        case lastsPast(Day)

        public var warn: Bool {
            switch self {
            case .belowForWholeRange, .runsOut: true
            default: false
            }
        }
    }

    public var runway: Runway {
        if start < 0 {
            if let b = backAbove { return b.overdue ? .backAboveOnce(b.label) : .backAboveOn(b.day) }
            return .belowForWholeRange
        }
        if let hitZero { return .runsOut(hitZero) }
        return .lastsPast(end)
    }
}

public struct EverydaySpending: Equatable, Sendable {
    /// A typical week of unscheduled spending.
    public var weekly: Cents
    /// How many full weeks it's based on.
    public var weeks: Int
    public var perDay: Cents { Int((Double(weekly) / 7).rounded()) }
}

public struct CategoryTotal: Identifiable, Equatable, Sendable {
    public var category: String
    public var cents: Cents
    public var count: Int
    public var id: String { category }
}

public struct Summary: Equatable, Sendable {
    public var spent: Cents
    public var income: Cents
    /// Spending by category, biggest first.
    public var byCategory: [CategoryTotal]
    /// Money in by category, biggest first.
    public var incomeByCategory: [CategoryTotal]
    public var net: Cents { income - spent }
}
