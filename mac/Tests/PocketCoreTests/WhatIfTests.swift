import XCTest
@testable import PocketCore

final class WhatIfTests: XCTestCase {
    private func day(_ s: String) -> Day { Day(iso: s)! }
    // A Monday.
    private let today = Day(iso: "2026-11-23")!

    private func parse(_ text: String, dayFirst: Bool = false) -> PurchaseIdea? {
        try? PurchaseParser.parse(text, today: today, dayFirst: dayFirst).get()
    }

    func testReadsAnAmountAndADay() {
        XCTAssertEqual(parse("$200 on Wednesday"), PurchaseIdea(cents: 20_000, day: day("2026-11-25")))
        XCTAssertEqual(parse("200 wed"), PurchaseIdea(cents: 20_000, day: day("2026-11-25")))
        XCTAssertEqual(parse("$45.50 tomorrow"), PurchaseIdea(cents: 4_550, day: day("2026-11-24")))
        XCTAssertEqual(parse("80"), PurchaseIdea(cents: 8_000, day: today), "No day means today")
        XCTAssertEqual(parse("$ 1,200 on Dec 3 for a new laptop"),
                       PurchaseIdea(cents: 120_000, day: day("2026-12-03"), label: "a new laptop"))
        XCTAssertEqual(parse("60 dollars in 2 weeks")?.day, day("2026-12-07"))
        XCTAssertEqual(parse("30 in a month")?.day, day("2026-12-23"))
        XCTAssertEqual(parse("12 on the 15th")?.day, day("2026-12-15"), "The 15th has passed, so it's next month's")
        XCTAssertEqual(parse("12 on the 30th")?.day, day("2026-11-30"))
        XCTAssertEqual(parse("75 on 3rd December")?.day, day("2026-12-03"))
        XCTAssertEqual(parse("75 on 12/3")?.day, day("2026-12-03"))
        XCTAssertEqual(parse("75 on 3/12", dayFirst: true)?.day, day("2026-12-03"))
        XCTAssertEqual(parse("75 on 2026-12-03")?.day, day("2026-12-03"))
        XCTAssertEqual(parse("75 on Jan 5")?.day, day("2027-01-05"), "A date already gone this year means next year")
        XCTAssertEqual(parse("Spend 20 on Friday for Groceries")?.label, "Groceries", "The name keeps its capitals")
    }

    func testWeekdaysCountTodayUnlessNextIsSaid() {
        XCTAssertEqual(parse("10 monday")?.day, today)
        XCTAssertEqual(parse("10 next monday")?.day, day("2026-11-30"))
        XCTAssertEqual(parse("10 on sunday")?.day, day("2026-11-29"))
    }

    func testExplainsWhatItCouldNotRead() {
        XCTAssertEqual(PurchaseParser.parse("on Wednesday", today: today), .failure(.noAmount))
        XCTAssertEqual(PurchaseParser.parse("200 someday", today: today), .failure(.unknownDay("someday")))
        XCTAssertEqual(PurchaseParser.parse("200 on 2026-11-01", today: today), .failure(.pastDay))
        XCTAssertEqual(PurchaseParser.parse("200 on 2028-01-01", today: today), .failure(.tooFar))
    }

    /// Rent Thursday and pay Friday: a $200 purchase Wednesday moves the low point and what's left until payday,
    /// without changing the ledger.
    func testPurchaseCheckComparesTheForecastWithoutSavingAnything() throws {
        var ledger = Ledger(entries: [Entry(cents: 100_000, label: "Opening balance", day: today)])
        ledger.addRule(Rule(cents: -80_000, label: "Rent", cadence: .monthly, anchor: day("2026-11-26")), today: today)
        ledger.addRule(Rule(cents: 150_000, label: "Paycheck", cadence: .biweekly, anchor: day("2026-11-27")), today: today)
        let idea = try PurchaseParser.parse("$200 on Wednesday", today: today).get()

        let check = ledger.checkPurchase(idea, today: today, days: 30, everyday: 0, payday: day("2026-11-27"))
        XCTAssertEqual(check.before.lowBalance, 20_000)
        XCTAssertEqual(check.after.lowBalance, 0)
        XCTAssertEqual(check.after.lowDay, day("2026-11-26"))
        XCTAssertTrue(check.lowersLowPoint)
        XCTAssertFalse(check.causesShortfall, "Zero is not below zero")
        XCTAssertEqual(check.paydayBefore?.lowBalance, 20_000)
        XCTAssertEqual(check.paydayAfter?.lowBalance, 0)
        XCTAssertEqual(ledger.rules.count, 2, "Checking doesn't plan anything")

        let bigger = PurchaseIdea(cents: 30_000, day: day("2026-11-25"))
        XCTAssertTrue(ledger.checkPurchase(bigger, today: today, days: 30, everyday: 0).causesShortfall)

        let afterPayday = PurchaseIdea(cents: 5_000, day: day("2026-11-28"))
        XCTAssertNil(ledger.checkPurchase(afterPayday, today: today, days: 30, everyday: 0, payday: day("2026-11-27")).paydayAfter,
                     "A purchase after payday doesn't change what's available before it")
    }

    func testTheRangeStretchesToCoverALaterPurchase() {
        let ledger = Ledger(entries: [Entry(cents: 10_000, label: "Opening balance", day: today)])
        let check = ledger.checkPurchase(PurchaseIdea(cents: 2_000, day: today.adding(days: 100)), today: today, days: 30, everyday: 0)
        XCTAssertEqual(check.after.end, today.adding(days: 114))
        XCTAssertEqual(check.after.endBalance, 8_000)
    }
}
