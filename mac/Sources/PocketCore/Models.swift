import Foundation

/// Money is stored in cents (whole numbers) so sums never drift.
public typealias Cents = Int

public enum Cadence: String, Codable, CaseIterable, Identifiable, Sendable {
    case weekly, biweekly, monthly, quarterly, yearly

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .weekly: "Weekly"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Monthly"
        case .quarterly: "Every 3 months"
        case .yearly: "Yearly"
        }
    }

    public var unit: String {
        switch self {
        case .weekly: "week"
        case .biweekly: "2 weeks"
        case .monthly: "month"
        case .quarterly: "3 months"
        case .yearly: "year"
        }
    }

    /// How many times it happens in an average month (for "≈ $X a month").
    public var perMonth: Double {
        switch self {
        case .weekly: 52.0 / 12
        case .biweekly: 26.0 / 12
        case .monthly: 1
        case .quarterly: 1.0 / 3
        case .yearly: 1.0 / 12
        }
    }

    /// Occurrence n is always counted from the anchor, so month ends don't drift (Jan 31 → Feb 28 → Mar 31).
    public func step(from anchor: Day, _ n: Int) -> Day {
        switch self {
        case .weekly: anchor.adding(days: 7 * n)
        case .biweekly: anchor.adding(days: 14 * n)
        case .monthly: anchor.adding(months: n)
        case .quarterly: anchor.adding(months: 3 * n)
        case .yearly: anchor.adding(years: n)
        }
    }
}

/// Something that already happened: money in (positive) or out (negative).
public struct Entry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var cents: Cents
    public var label: String
    public var day: Day
    public var category: String?
    /// Set when a repeating payment logged it.
    public var ruleID: UUID?
    public var created: Date

    public init(id: UUID = UUID(), cents: Cents, label: String, day: Day, category: String? = nil,
                ruleID: UUID? = nil, created: Date = Date()) {
        self.id = id
        self.cents = cents
        self.label = label
        self.day = day
        self.category = category
        self.ruleID = ruleID
        self.created = created
    }
}

/// Money that repeats (a subscription, a paycheck), or one expected payment (total == 1).
public struct Rule: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var cents: Cents
    public var label: String
    public var cadence: Cadence
    /// The first payment; occurrence n is `cadence.step(from: anchor, n)`.
    public var anchor: Day
    /// Occurrences already logged (or skipped).
    public var posted: Int
    /// nil = keeps going forever.
    public var total: Int?
    public var active: Bool
    /// false = don't log it by itself; wait until the user confirms it arrived.
    public var auto: Bool
    public var category: String?
    /// Separate from the category. nil recognizes older subscription-category rules.
    public var subscription: Bool?
    /// The server distinguishes a one-time payment from the last renewal of a finite schedule.
    public var once: Bool?
    public var created: Date

    public init(id: UUID = UUID(), cents: Cents, label: String, cadence: Cadence, anchor: Day, posted: Int = 0,
                total: Int? = nil, active: Bool = true, auto: Bool = true, category: String? = nil,
                created: Date = Date(), subscription: Bool? = nil, once: Bool? = nil) {
        self.id = id
        self.cents = cents
        self.label = label
        self.cadence = cadence
        self.anchor = anchor
        self.posted = posted
        self.total = total
        self.active = active
        self.auto = auto
        self.category = category
        self.subscription = subscription
        self.once = once
        self.created = created
    }

    public var isOnce: Bool { once ?? (total == 1) }
    public var isSubscription: Bool { cents < 0 && !isOnce && (subscription ?? (category == "subscriptions")) }
    public var finished: Bool { total.map { posted >= $0 } ?? false }
    public var remaining: Int? { total.map { max(0, $0 - posted) } }
    public func occurrence(_ n: Int) -> Day { cadence.step(from: anchor, n) }
    public var next: Day { occurrence(posted) }

    /// The next payment, the one "Got it" and "Skip" act on.
    public func nextOccurrence(today: Day) -> Occurrence {
        Occurrence(ruleID: id, label: label, cents: cents, category: category, day: next, overdue: next <= today, isNext: true)
    }
}

/// A quick-add button. `cents == nil` means "ask for the amount each time".
public struct Preset: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var label: String
    public var cents: Cents?
    /// -1 spending, +1 money in.
    public var sign: Int
    public var category: String?

    public init(id: UUID = UUID(), label: String, cents: Cents?, sign: Int, category: String?) {
        self.id = id
        self.label = label
        self.cents = cents
        self.sign = sign < 0 ? -1 : 1
        self.category = category
    }
}

/// A future (or overdue) payment of a rule.
public struct Occurrence: Identifiable, Equatable, Sendable {
    public var ruleID: UUID
    public var label: String
    public var cents: Cents
    public var category: String?
    public var day: Day
    /// Due on or before today but not confirmed yet (only rules that wait for confirmation).
    public var overdue: Bool
    /// The next payment of its rule (the one "Got it" / "Skip" act on).
    public var isNext: Bool

    public var id: String { ruleID.uuidString + day.iso }
}

/// Everything a person has. Saved as one JSON file.
public struct Ledger: Codable, Equatable, Sendable {
    public var version: Int
    public var currency: String
    public var entries: [Entry]
    public var rules: [Rule]
    public var presets: [Preset]

    public init(currency: String = "USD", entries: [Entry] = [], rules: [Rule] = [], presets: [Preset] = []) {
        self.version = 1
        self.currency = currency
        self.entries = entries
        self.rules = rules
        self.presets = presets
    }

    /// Check external data before it can replace the saved ledger or reach money arithmetic.
    public func validate() throws {
        guard version == 1 else { throw LedgerError("This file uses an unsupported Pocket version.") }
        guard Locale.commonISOCurrencyCodes.contains(currency) else { throw LedgerError("This file has an unrecognized currency.") }
        guard Set(entries.map(\.id)).count == entries.count,
              Set(rules.map(\.id)).count == rules.count,
              Set(presets.map(\.id)).count == presets.count else { throw LedgerError("This file contains duplicate identifiers.") }
        let amountRange = -99_999_999_999...99_999_999_999
        var exposure = 0
        func include(_ cents: Cents, multiplier: Int = 1) throws {
            guard amountRange.contains(cents) else { throw LedgerError("This file contains an amount outside Pocket's supported range.") }
            let (total, overflow) = exposure.addingReportingOverflow(abs(cents) * multiplier)
            guard !overflow else { throw LedgerError("The totals in this file are too large.") }
            exposure = total
        }
        for entry in entries { try include(entry.cents) }
        for rule in rules {
            guard (0...1_000_000).contains(rule.posted),
                  rule.total.map({ (0...1_000_000).contains($0) && rule.posted <= $0 }) ?? true else {
                throw LedgerError("This file contains an invalid payment schedule.")
            }
            try include(rule.cents, multiplier: 400)
        }
        for preset in presets {
            guard [-1, 1].contains(preset.sign), preset.cents.map({ $0 > 0 && amountRange.contains($0) }) ?? true else {
                throw LedgerError("This file contains an invalid quick-add amount or direction.")
            }
        }
    }
}

public struct LedgerError: LocalizedError {
    public let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
