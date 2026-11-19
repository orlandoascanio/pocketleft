import XCTest
@testable import PocketCore

final class EngineTests: XCTestCase {
    private func day(_ s: String) -> Day { Day(iso: s)! }

    func testDayMathClampsMonthEnds() {
        let jan31 = day("2026-01-31")
        XCTAssertEqual(Cadence.monthly.step(from: jan31, 1), day("2026-02-28"))
        XCTAssertEqual(Cadence.monthly.step(from: jan31, 2), day("2026-03-31"))
        XCTAssertEqual(Cadence.yearly.step(from: day("2028-02-29"), 1), day("2029-02-28"))
        XCTAssertEqual(Cadence.biweekly.step(from: day("2026-10-17"), 1), day("2026-10-31"))
        XCTAssertEqual(day("2026-10-11").days(until: day("2026-10-20")), 9)
    }

    func testBalanceAndEntries() {
        var l = Ledger()
        l.add(Entry(cents: 24_100, label: "Start", day: day("2026-10-01"), category: Categories.start))
        l.add(Entry(cents: -999, label: "Game", day: day("2026-10-02"), category: "games"))
        XCTAssertEqual(l.balance, 23_101)
        let id = l.entries[1].id
        l.removeEntry(id)
        XCTAssertEqual(l.balance, 24_100)
    }

    func testAutomaticRuleLogsDueDatesAndStopsAfterTotal() {
        var l = Ledger()
        l.addRule(Rule(cents: -500, label: "Month end", cadence: .monthly, anchor: day("2026-01-31"), total: 3,
                       category: "bills"), today: day("2026-04-15"))
        XCTAssertEqual(l.entries.map(\.day.iso).sorted(), ["2026-01-31", "2026-02-28", "2026-03-31"])
        l.postDue(today: day("2026-12-31"))
        XCTAssertEqual(l.entries.count, 3, "stops after 3 payments")
        XCTAssertTrue(l.rules[0].finished)
        XCTAssertTrue(l.liveRules.isEmpty, "finished rules drop out")
        XCTAssertEqual(l.entries.first?.category, "bills")
    }

    func testIncomeThatWaitsForConfirmation() {
        var l = Ledger()
        l.addRule(Rule(cents: 75_000, label: "Client", cadence: .monthly, anchor: day("2026-10-05"), auto: false),
                  today: day("2026-10-11"))
        XCTAssertTrue(l.entries.isEmpty, "not logged by itself")
        let waiting = l.waiting(today: day("2026-10-11"))
        XCTAssertEqual(waiting.count, 1)
        XCTAssertTrue(waiting[0].overdue)

        // It arrived late and smaller.
        let id = l.rules[0].id
        l.settle(id, cents: 70_000, on: day("2026-10-09"), today: day("2026-10-11"))
        XCTAssertEqual(l.balance, 70_000)
        XCTAssertEqual(l.entries[0].day, day("2026-10-09"))
        XCTAssertEqual(l.rules[0].cents, 75_000, "the plan keeps its amount")
        XCTAssertEqual(l.rules[0].next, day("2026-11-05"))
        XCTAssertTrue(l.waiting(today: day("2026-10-11")).isEmpty)

        l.skip(id)
        XCTAssertEqual(l.rules[0].next, day("2026-12-05"))
        XCTAssertEqual(l.entries.count, 1, "skip logs nothing")
    }

    func testPauseDoesNotLogAndResumeDoesNotBackLog() {
        var l = Ledger()
        l.addRule(Rule(cents: -2_000, label: "Sub", cadence: .monthly, anchor: day("2026-10-01")), today: day("2026-10-11"))
        let id = l.rules[0].id
        l.setActive(id, false, today: day("2026-10-11"))
        l.postDue(today: day("2027-01-15"))
        XCTAssertEqual(l.entries.count, 1)
        l.setActive(id, true, today: day("2027-01-15"))
        XCTAssertEqual(l.entries.count, 1, "missed payments aren't added")
        XCTAssertEqual(l.rules[0].next, day("2027-02-01"))
    }

    func testUpdateRuleReanchorsOnlyWhenScheduleChanges() {
        var l = Ledger()
        l.addRule(Rule(cents: 75_000, label: "Client", cadence: .monthly, anchor: day("2026-09-20"), total: 3),
                  today: day("2026-10-11"))
        XCTAssertEqual(l.entries.count, 1)
        let id = l.rules[0].id
        // Same schedule, fewer payments left.
        l.updateRule(id, cents: 80_000, label: "Client A", cadence: .monthly, next: day("2026-10-20"), left: 1,
                     category: "pay", auto: true, today: day("2026-10-11"))
        XCTAssertEqual(l.rules[0].remaining, 1)
        XCTAssertEqual(l.rules[0].next, day("2026-10-20"))
        // Moved date: restarts from the new date.
        l.updateRule(id, cents: 80_000, label: "Client A", cadence: .monthly, next: day("2026-10-25"), left: 2,
                     category: "pay", auto: true, today: day("2026-10-11"))
        XCTAssertEqual(l.rules[0].next, day("2026-10-25"))
        XCTAssertEqual(l.rules[0].remaining, 2)
    }

    func testUpcomingRespectsLimitsAndHorizon() {
        var l = Ledger()
        l.addRule(Rule(cents: 75_000, label: "Freelance", cadence: .monthly, anchor: day("2026-09-20"), total: 3),
                  today: day("2026-10-11"))
        l.addRule(Rule(cents: 30_000, label: "Expected", cadence: .monthly, anchor: day("2026-10-18"), total: 1),
                  today: day("2026-10-11"))
        let up = l.upcoming(today: day("2026-10-11"), days: 120)
        XCTAssertEqual(up.map(\.label), ["Expected", "Freelance", "Freelance"])
        XCTAssertEqual(up.filter(\.isNext).count, 2)
        XCTAssertEqual(l.balance, 75_000, "future money doesn't count yet")
    }

    func testRunway() {
        var l = Ledger()
        l.add(Entry(cents: -5_908, label: "Spent", day: day("2026-10-01")))
        l.addRule(Rule(cents: 75_000, label: "Client", cadence: .monthly, anchor: day("2026-10-05"), auto: false),
                  today: day("2026-10-11"))
        XCTAssertEqual(l.project(today: day("2026-10-11"), days: 91).runway, .backAboveOnce("Client"))

        var m = Ledger()
        m.add(Entry(cents: 5_000, label: "Cash", day: day("2026-10-01")))
        m.addRule(Rule(cents: -2_000, label: "Sub", cadence: .monthly, anchor: day("2026-10-20")), today: day("2026-10-11"))
        let p = m.project(today: day("2026-10-11"), days: 91)
        XCTAssertEqual(p.runway, .runsOut(day("2026-12-20")))
        XCTAssertEqual(p.endBalance, 5_000 - 3 * 2_000)
        XCTAssertTrue(p.runway.warn)

        var n = Ledger()
        n.add(Entry(cents: 5_000, label: "Cash", day: day("2026-10-01")))
        XCTAssertEqual(n.project(today: day("2026-10-11"), days: 30).runway, .lastsPast(day("2026-11-10")))
    }

    func testSummaryExcludesStartingBalance() {
        var l = Ledger()
        l.add(Entry(cents: 24_100, label: "Start", day: day("2026-10-01"), category: Categories.start))
        l.add(Entry(cents: -1_499, label: "DST", day: day("2026-10-02"), category: "games"))
        l.add(Entry(cents: -999, label: "Valorant", day: day("2026-10-03"), category: "games"))
        l.add(Entry(cents: -4_000, label: "Internet", day: day("2026-10-04"), category: "bills"))
        l.add(Entry(cents: -2_000, label: "Old", day: day("2026-09-04"), category: "subscriptions"))
        l.add(Entry(cents: 10_000, label: "Gift", day: day("2026-10-05"), category: "gift"))
        let oct = l.summary(YearMonth(year: 2026, month: 10))
        XCTAssertEqual(oct.spent, 6_498)
        XCTAssertEqual(oct.income, 10_000)
        XCTAssertEqual(oct.byCategory.map(\.category), ["bills", "games"], "biggest first")
        XCTAssertEqual(oct.byCategory[1].count, 2)
        XCTAssertEqual(l.summary(nil).spent, 8_498)
        XCTAssertEqual(l.firstMonth, YearMonth(year: 2026, month: 9))
    }

    func testSpendingComparisonRequiresCompletedMonths() {
        let ledger = Ledger(entries: [Entry(cents: 1_000, label: "Start", day: day("2026-02-01"), category: Categories.start)])
        let today = day("2026-04-19")
        XCTAssertNil(ledger.previousSpendingPeriod(for: today.yearMonth, today: today))
        XCTAssertEqual(ledger.previousSpendingPeriod(for: day("2026-03-01").yearMonth, today: today), day("2026-02-01")...day("2026-02-28"))
        let midMonthStart = Ledger(entries: [Entry(cents: 1_000, label: "Start", day: day("2026-03-05"), category: Categories.start)])
        XCTAssertNil(midMonthStart.previousSpendingPeriod(for: today.yearMonth, today: day("2026-05-01")))
    }

    func testUncategorizedSummaryAndHistoryAgreeWithinTheSelectedDates() {
        let ledger = Ledger(entries: [
            Entry(cents: -9_584, label: "Other", day: day("2026-11-01"), category: "other"),
            Entry(cents: -907, label: "Missing expense category", day: day("2026-11-02")),
            Entry(cents: 30_000, label: "Missing income category", day: day("2026-11-03")),
            Entry(cents: -400, label: "Upcoming expense", day: day("2026-11-25")),
        ])
        let period = day("2026-11-01")...day("2026-11-19")
        let summary = ledger.summary(in: period)
        XCTAssertEqual(summary.spent, 10_491)
        XCTAssertEqual(summary.byCategory.map(\.category), ["other", Categories.uncategorized])
        XCTAssertEqual(summary.incomeByCategory.map(\.category), [Categories.uncategorized])
        for kind in [EntryQuery.Kind.spending, .income] {
            let query = EntryQuery(kind: kind, category: Categories.uncategorized, from: period.lowerBound, to: period.upperBound)
            XCTAssertEqual(ledger.search(query).map(\.label), [kind == .spending ? "Missing expense category" : "Missing income category"])
        }
    }

    func testGuessCategory() {
        var l = Ledger()
        l.add(Entry(cents: -999, label: "Valorant", day: day("2026-10-03"), category: "games"))
        XCTAssertEqual(l.guessCategory(for: "valo", income: false), "games")
        XCTAssertNil(l.guessCategory(for: "va", income: false), "too short")
        XCTAssertNil(l.guessCategory(for: "valo", income: true), "wrong side")
    }

    func testMoneyParseAndFormat() {
        XCTAssertEqual(Money.parse("9.99"), 999)
        XCTAssertEqual(Money.parse("9,99"), 999)
        XCTAssertEqual(Money.parse("$1,234.50"), 123_450)
        XCTAssertEqual(Money.parse("1.234,50"), 123_450)
        XCTAssertEqual(Money.parse("750"), 75_000)
        XCTAssertNil(Money.parse("0"))
        XCTAssertNil(Money.parse("abc"))
        let usd = Money(currency: "USD", locale: Locale(identifier: "en_US"))
        XCTAssertEqual(usd.string(-5_908), "-$59.08")
        XCTAssertEqual(usd.string(75_000, signed: true), "+$750.00")
        XCTAssertEqual(usd.whole(75_049), "$750")
    }

    func testLedgerRoundTripsThroughJSON() throws {
        var l = Ledger(currency: "EUR")
        l.add(Entry(cents: -999, label: "Game", day: day("2026-10-03"), category: "games"))
        l.addRule(Rule(cents: 75_000, label: "Client", cadence: .monthly, anchor: day("2026-11-05"), auto: false),
                  today: day("2026-10-11"))
        l.presets.append(Preset(label: "Valorant", cents: 999, sign: -1, category: "games"))
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let back = try dec.decode(Ledger.self, from: enc.encode(l))
        XCTAssertEqual(back.entries.map(\.label), l.entries.map(\.label))
        XCTAssertEqual(back.rules[0].anchor, day("2026-11-05"))
        XCTAssertEqual(back.currency, "EUR")
        XCTAssertEqual(back.presets[0].cents, 999)
    }

    func testAmountsRejectMalformedInputInsteadOfChangingItsMeaning() {
        for text in ["abc12", "12abc", "1$2", "1-2", "--12", "9..99", "1,23,456", "12.3456", ".", ",", "1000000000"] {
            XCTAssertNil(Money.parse(text, allowZero: true), text)
        }
        XCTAssertEqual(Money.parse(".05"), 5)
        XCTAssertEqual(Money.parse("+12.50"), 1250)
        XCTAssertEqual(Money.parse("1,234,567.89"), 123456789)
        XCTAssertEqual(Money.parse("1.234.567,89"), 123456789)
        XCTAssertEqual(Money.parse("999999999.99"), 99999999999)
        XCTAssertEqual(Money.parse("0.00", allowZero: true), 0)
        XCTAssertNil(Money.parse("0.00"))
        let yen = Money(currency: "JPY", locale: Locale(identifier: "en_US"))
        XCTAssertEqual(yen.placeholder, "0.00")
        XCTAssertTrue(yen.string(12345).contains("123.45"), "a fractional recorded balance must remain visible")
    }

    func testDatesRejectNonexistentDaysAndMalformedExports() {
        for date in ["2026-02-29", "2026-04-31", "2026-00-01", "2026--10-01", "2026-1-01", "0000-01-01", "2026-10-01-extra"] {
            XCTAssertNil(Day(iso: date), date)
        }
        XCTAssertNotNil(Day(iso: "2028-02-29"))
    }

    func testExternalLedgerValidationRejectsUnsafeData() throws {
        let entry = Entry(cents: 1000, label: "Start", day: day("2026-10-12"))
        XCTAssertThrowsError(try Ledger(entries: [entry, entry]).validate())
        XCTAssertThrowsError(try Ledger(entries: [Entry(cents: Int.min, label: "Invalid", day: entry.day)]).validate())
        XCTAssertThrowsError(try Ledger(rules: [Rule(cents: 100, label: "Invalid", cadence: .monthly, anchor: entry.day, posted: -1)]).validate())
        XCTAssertThrowsError(try Ledger(presets: [Preset(label: "Invalid", cents: -100, sign: -1, category: nil)]).validate())
        var future = Ledger(); future.version = 2
        XCTAssertThrowsError(try future.validate())
        XCTAssertNoThrow(try Ledger(entries: [entry]).validate())
    }

    func testLinesDontRepeatUntilTheDeckRunsOut() {
        let lines = Lines()
        let pool = Lines.pools["poke"]!
        let dealt = (0..<pool.count).map { _ in lines.line("poke") }
        XCTAssertEqual(Set(dealt).count, pool.count)
    }
}
