import Foundation
import PocketCore
import XCTest
@testable import Pocket

final class HistorySnapshotTests: XCTestCase {
    func testFilteringPreservesBalancesFromTheFullLedger() {
        let day = Day(year: 2026, month: 11, day: 15)
        let entries = (0..<250).map { i in
            Entry(cents: i == 0 ? 100_000 : -100, label: i % 2 == 0 ? "Coffee" : "Other",
                  day: day, created: Date(timeIntervalSince1970: Double(i)))
        }
        var history = HistorySnapshot(entries: entries)
        XCTAssertEqual(history.entries.first?.id, entries.last?.id)
        XCTAssertEqual(history.balanceAfter[entries[0].id], 100_000)
        XCTAssertEqual(history.balanceAfter[entries[249].id], 75_100)
        XCTAssertEqual(history.matching.count, 250)
        XCTAssertEqual(history.netByDay[day], 75_100, "Daily totals must include rows beyond the display page")
        XCTAssertEqual(history.balanceAfter[history.matching[100].id], 85_100)
        history.filter(EntryQuery(text: "Coffee"))
        XCTAssertEqual(history.matching.count, 125, "Filtering searches beyond the first display page")
        XCTAssertEqual(history.netByDay[day], 87_600, "Daily totals follow the full search result")
        XCTAssertEqual(history.matching.first?.id, entries[248].id)
        XCTAssertEqual(history.balanceAfter[entries[248].id], 75_200, "Hidden entries still affect the balance")
        history.filter(EntryQuery())
        XCTAssertEqual(history.matching.count, 250)
    }

    func testReplacingEntriesRebuildsRunningBalances() {
        let entry = Entry(cents: 100, label: "Income", day: .today)
        var edited = entry
        edited.cents = 200
        let old = HistorySnapshot(entries: [entry])
        let new = HistorySnapshot(entries: [edited], query: EntryQuery(text: "missing"))
        XCTAssertEqual(old.balanceAfter[entry.id], 100)
        XCTAssertEqual(new.balanceAfter[entry.id], 200)
        XCTAssertTrue(new.matching.isEmpty)
    }
}
