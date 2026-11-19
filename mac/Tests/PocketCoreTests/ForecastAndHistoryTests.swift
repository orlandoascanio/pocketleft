import XCTest
@testable import PocketCore

// Mirrored by mobile/src/core/__tests__/forecast-history.test.ts, so both apps agree.
final class ForecastAndHistoryTests: XCTestCase {
    private func day(_ s: String) -> Day { Day(iso: s)! }

    func testQuarterlyCountsThreeMonthsFromTheAnchor() {
        let nov30 = day("2025-11-30")
        XCTAssertEqual(Cadence.quarterly.step(from: nov30, 1), day("2026-02-28"))
        XCTAssertEqual(Cadence.quarterly.step(from: nov30, 2), day("2026-05-30"))
        XCTAssertEqual(Cadence.quarterly.step(from: nov30, 4), day("2026-11-30"))
        var l = Ledger()
        l.addRule(Rule(cents: -3_000, label: "Insurance", cadence: .quarterly, anchor: nov30), today: day("2026-06-01"))
        XCTAssertEqual(l.entries.map(\.day.iso).sorted(), ["2025-11-30", "2026-02-28", "2026-05-30"])
        let json = try! JSONEncoder().encode(l)
        XCTAssertEqual(try JSONDecoder().decode(Ledger.self, from: json).rules[0].cadence, .quarterly)
    }

    /// The median of six full weeks: the laptop doesn't count as a usual week, and scheduled money, income,
    /// today and days before the window are left out.
    func testEverydaySpendingIsTheMedianWeekOfUnscheduledSpending() {
        var l = Ledger()
        l.add(Entry(cents: 100_000, label: "Starting balance", day: day("2026-09-01"), category: Categories.start))
        l.add(Entry(cents: -10_000, label: "Before the window", day: day("2026-09-02")))
        for (cents, d) in [(-2_000, "2026-10-14"), (-1_500, "2026-10-10"), (-3_000, "2026-10-03"), (-150_000, "2026-09-25"),
                           (-4_000, "2026-09-20"), (-2_500, "2026-09-12"), (-3_200, "2026-09-05")] {
            l.add(Entry(cents: cents, label: "Spent", day: day(d), category: "food"))
        }
        l.add(Entry(cents: -9_000, label: "Rent", day: day("2026-09-28"), ruleID: UUID()))
        l.add(Entry(cents: 50_000, label: "Pay", day: day("2026-10-01"), category: "pay"))
        l.add(Entry(cents: -700, label: "Today", day: day("2026-10-15")))
        let e = l.everydaySpending(today: day("2026-10-15"))
        XCTAssertEqual(e, EverydaySpending(weekly: 3_350, weeks: 6))
        XCTAssertEqual(e?.perDay, 479)

        var fresh = Ledger()
        fresh.add(Entry(cents: -500, label: "Snack", day: day("2026-10-05")))
        XCTAssertNil(fresh.everydaySpending(today: day("2026-10-15")), "needs two full weeks")
    }

    func testEverydaySpendingSlopesTheForecastAndMovesTheRunway() {
        var l = Ledger()
        l.add(Entry(cents: 10_000, label: "Cash", day: day("2026-10-01")))
        l.addRule(Rule(cents: -5_000, label: "Bill", cadence: .monthly, anchor: day("2026-10-05")), today: day("2026-10-01"))

        let plain = l.project(today: day("2026-10-01"), days: 30)
        XCTAssertEqual(plain.endBalance, 5_000)
        XCTAssertEqual(plain.runway, .lastsPast(day("2026-10-31")))

        let p = l.project(today: day("2026-10-01"), days: 30, everyday: 1_000)
        XCTAssertEqual(p.everyday, 1_000)
        XCTAssertEqual(p.points.count, 2)
        XCTAssertEqual(p.points[1].before, 6_000, "four days of everyday spending before the bill")
        XCTAssertEqual(p.points[1].balance, 1_000)
        XCTAssertEqual(p.steps[0].after, 1_000)
        XCTAssertEqual(p.endBalance, -25_000)
        XCTAssertEqual(p.runway, .runsOut(day("2026-10-07")), "0 left on the 6th, below zero on the 7th")
        XCTAssertEqual(p.lowBalance, -25_000)
        XCTAssertEqual(p.lowDay, day("2026-10-31"))
    }

    func testMonthsLeftAtTheUsualPace() {
        XCTAssertEqual(Ledger.monthsLeft(balance: 10_000, everyday: 0, repeating: [(-5_000, .monthly), (2_000, .monthly)])!, 10.0 / 3, accuracy: 0.0001)
        XCTAssertEqual(Ledger.monthsLeft(balance: 10_000, everyday: 100, repeating: [(-3_000, .quarterly)])!, 10_000 / (100 * 365.25 / 12 + 1_000), accuracy: 0.0001)
        XCTAssertNil(Ledger.monthsLeft(balance: 10_000, everyday: 0, repeating: [(-1_000, .monthly), (2_000, .monthly)]), "money goes up")
        XCTAssertNil(Ledger.monthsLeft(balance: 0, everyday: 500, repeating: []), "nothing left")
    }

    private func searchLedger() -> Ledger {
        var l = Ledger()
        l.add(Entry(cents: 5_000, label: "Starting balance", day: day("2026-09-01"), category: Categories.start))
        l.add(Entry(cents: -380, label: "Café Olé", day: day("2026-09-20"), category: "food"))
        l.add(Entry(cents: 200_000, label: "Paycheck", day: day("2026-10-01"), category: "pay"))
        l.add(Entry(cents: -999, label: "Valorant points", day: day("2026-10-02"), category: "games"))
        l.add(Entry(cents: -1_234, label: "Thing", day: day("2026-10-05")))
        l.add(Entry(cents: -450, label: "Coffee", day: day("2026-10-10"), category: "food"))
        return l
    }

    func testSearchMatchesLabelsCategoriesAndAmounts() {
        let l = searchLedger()
        let labels = { (q: EntryQuery) in l.search(q).map(\.label) }
        XCTAssertEqual(labels(EntryQuery(text: "cafe")), ["Café Olé"], "ignores accents and case")
        XCTAssertEqual(labels(EntryQuery(text: "food 4")), ["Coffee"], "every word has to match")
        XCTAssertEqual(labels(EntryQuery(text: "12.34")), ["Thing"])
        XCTAssertEqual(labels(EntryQuery(kind: .income)), ["Paycheck"], "the starting balance isn't income")
        XCTAssertEqual(labels(EntryQuery(kind: .spending)), ["Coffee", "Thing", "Valorant points", "Café Olé"])
        XCTAssertTrue(labels(EntryQuery(category: "other")).isEmpty)
        XCTAssertEqual(labels(EntryQuery(category: Categories.uncategorized)), ["Thing"])
        XCTAssertEqual(labels(EntryQuery(category: nil, month: YearMonth(year: 2026, month: 10))).count, 4)
        XCTAssertTrue(EntryQuery(text: "  ").isEmpty)
    }

    func testQuickDateRanges() {
        let today = day("2026-03-15")
        XCTAssertTrue(EntryQuery.Period.lastMonth.range(today: today) == (day("2026-02-01"), day("2026-02-28")))
        XCTAssertTrue(EntryQuery.Period.last3Months.range(today: today) == (day("2026-01-01"), today))
        XCTAssertTrue(EntryQuery.Period.thisYear.range(today: today) == (day("2026-01-01"), today))
        let (from, to) = EntryQuery.Period.lastMonth.range(today: today)
        let q = EntryQuery(from: from, to: to)
        XCTAssertEqual(q.period(today: today), .lastMonth)
        XCTAssertEqual(q.month, YearMonth(year: 2026, month: 2))
        XCTAssertNil(EntryQuery(from: day("2026-02-02"), to: to).month)
    }

    func testCSVQuotesTextAndKeepsFormulasOut() {
        let entries = [
            Entry(cents: 300, label: "=SUM(A1)", day: day("2026-09-03"), ruleID: UUID()),
            Entry(cents: 5_000, label: "Starting balance", day: day("2026-09-01"), category: Categories.start),
            Entry(cents: -1_250, label: "Lunch, with \"Sam\"", day: day("2026-09-02"), category: "food"),
        ]
        XCTAssertEqual(CSV.entries(entries, currency: "USD"),
                       "\u{FEFF}Date,Description,Category,Amount,Currency,Type,Scheduled\r\n"
                       + "2026-09-01,Starting balance,Starting balance,50.00,USD,Starting balance,No\r\n"
                       + "2026-09-02,\"Lunch, with \"\"Sam\"\"\",Food,-12.50,USD,Spent,No\r\n"
                       + "2026-09-03,'=SUM(A1),,3.00,USD,Money in,Yes\r\n")
        XCTAssertEqual(CSV.amount(-5), "-0.05")
    }
}
