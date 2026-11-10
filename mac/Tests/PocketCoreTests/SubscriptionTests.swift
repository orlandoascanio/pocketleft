import Foundation
import XCTest
@testable import PocketCore

final class SubscriptionTests: XCTestCase {
    private let today = Day(iso: "2026-11-09")!

    func testLegacyMembershipAndExplicitOverridesPreserveCategories() throws {
        let legacy = Rule(cents: -999, label: "Music", cadence: .monthly, anchor: today, category: "subscriptions")
        let data = try JSONEncoder().encode(legacy)
        XCTAssertTrue(try JSONDecoder().decode(Rule.self, from: data).isSubscription)
        var excluded = legacy
        excluded.subscription = false
        XCTAssertFalse(try JSONDecoder().decode(Rule.self, from: JSONEncoder().encode(excluded)).isSubscription)
        let included = Rule(cents: -1500, label: "Cloud", cadence: .yearly, anchor: today, category: "apps", subscription: true)
        XCTAssertTrue(included.isSubscription)
        XCTAssertEqual(included.category, "apps")
        var income = legacy; income.cents = 999
        var once = legacy; once.total = 1
        XCTAssertFalse(income.isSubscription)
        XCTAssertFalse(once.isSubscription)
    }

    func testTotalsNormalizeCadencesAndExcludePausedFinishedAndNonSubscriptions() {
        let rules = [
            Rule(cents: -100, label: "Weekly", cadence: .weekly, anchor: today, subscription: true),
            Rule(cents: -100, label: "Fortnightly", cadence: .biweekly, anchor: today, subscription: true),
            Rule(cents: -100, label: "Monthly", cadence: .monthly, anchor: today, subscription: true),
            Rule(cents: -100, label: "Quarterly", cadence: .quarterly, anchor: today, subscription: true),
            Rule(cents: -100, label: "Yearly", cadence: .yearly, anchor: today, subscription: true),
            Rule(cents: -99999, label: "Paused", cadence: .monthly, anchor: today, active: false, subscription: true),
            Rule(cents: -99999, label: "Finished", cadence: .monthly, anchor: today, posted: 2, total: 2, subscription: true),
            Rule(cents: -99999, label: "Rent", cadence: .monthly, anchor: today, category: "bills"),
        ]
        let summary = SubscriptionSummary(ledger: Ledger(rules: rules), today: today)
        XCTAssertEqual(summary.active.count, 5)
        XCTAssertEqual(summary.paused.count, 1)
        XCTAssertEqual(summary.otherRepeating.map(\.label), ["Rent"])
        XCTAssertEqual(summary.annual, 9500)
        XCTAssertEqual(summary.monthly, 792)
    }

    func testRenewalsCountEveryChargeInWindowAndKeepOverdueSeparate() {
        let weekly = Rule(cents: -500, label: "Weekly", cadence: .weekly, anchor: today.adding(days: 1), subscription: true)
        let overdue = Rule(cents: -1000, label: "Overdue", cadence: .monthly, anchor: today.adding(days: -2), auto: false, subscription: true)
        let ledger = Ledger(rules: [weekly, overdue])
        let short = SubscriptionSummary(ledger: ledger, today: today, days: 7)
        XCTAssertEqual(short.renewals.map(\.label), ["Weekly"])
        XCTAssertEqual(short.overdue.map(\.label), ["Overdue"])
        let summary = SubscriptionSummary(ledger: ledger, today: today, days: 30)
        XCTAssertEqual(summary.renewals.filter { $0.label == "Weekly" }.count, 5)
        XCTAssertEqual(summary.upcomingTotal, 3500)
        XCTAssertTrue(summary.renewals.allSatisfy { $0.day >= today })
        XCTAssertEqual(ledger.entries.count, 0, "Opening Subscriptions must never log money")
    }

    func testMembershipSurvivesOrdinaryRuleEdits() {
        let rule = Rule(cents: -999, label: "Cloud", cadence: .monthly, anchor: today.adding(days: 1), category: "apps", subscription: true)
        var ledger = Ledger(rules: [rule])
        ledger.updateRule(rule.id, cents: -1200, label: "Cloud Pro", cadence: .monthly, next: rule.next,
                          left: nil, category: "apps", auto: true, today: today)
        XCTAssertTrue(ledger.rules[0].isSubscription)
        XCTAssertEqual(ledger.rules[0].category, "apps")
        ledger.updateRule(rule.id, cents: -1200, label: "Cloud Pro", cadence: .monthly, next: rule.next,
                          left: nil, category: "apps", auto: true, today: today, subscription: false)
        XCTAssertFalse(ledger.rules[0].isSubscription)
        XCTAssertEqual(ledger.entries.count, 0)
    }

    func testLastRenewalOfFiniteSubscriptionStillAppears() {
        let last = Rule(cents: -999, label: "Last renewal", cadence: .monthly, anchor: today.adding(days: 1),
                        total: 1, subscription: true, once: false)
        let summary = SubscriptionSummary(ledger: Ledger(rules: [last]), today: today)
        XCTAssertEqual(summary.active.count, 1)
        XCTAssertEqual(summary.renewals.count, 1)
    }
}
