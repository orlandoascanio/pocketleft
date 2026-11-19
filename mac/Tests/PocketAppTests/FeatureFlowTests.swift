import Foundation
import PocketCore
import XCTest
@testable import Pocket

/// Flows the download page and guides describe: money still on its way, quick-add buttons made from
/// an entry, the Quick Add menu, and restoring one of the daily backups.
@MainActor
final class FeatureFlowTests: XCTestCase {
    private func isolatedStore(directory: URL? = nil) throws -> Store {
        let directory = directory ?? FileManager.default.temporaryDirectory.appendingPathComponent("pocket-features-\(UUID())")
        let suite = "pocket-features-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(false, forKey: "reminders")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        return Store(directory: directory, defaults: defaults, servicesEnabled: false)
    }

    func testMoneyStillOwedWaitsWithoutChangingTheBalance() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 50_000, openAtLogin: false))
        let state = EditorState(); state.store = store
        state.spent = false
        state.amount = "50"
        state.label = "Sam owes me"
        XCTAssertFalse(state.isPlanned, "A plain entry dated today counts right away")
        state.awaiting = true
        XCTAssertTrue(state.waitsNow)
        XCTAssertTrue(state.save())
        XCTAssertEqual(store.balance, 50_000)
        let waiting = try XCTUnwrap(store.waiting.first)
        XCTAssertEqual(waiting.label, "Sam owes me")
        XCTAssertEqual(waiting.cents, 5_000)
        XCTAssertTrue(store.settle(waiting, cents: 4_000, on: .today))
        XCTAssertEqual(store.balance, 54_000)
        XCTAssertTrue(store.waiting.isEmpty)
        XCTAssertTrue(store.ledger.liveRules.isEmpty, "A one-time payment is done once it's confirmed")
    }

    func testShareNoteAppearsOnceAfterTheFirstGotIt() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 50_000, openAtLogin: false))
        for i in 0..<30 { XCTAssertNotNil(store.addEntry(cents: -100, label: "Coffee \(i)", day: .today, category: "food")) }
        XCTAssertFalse(store.showSharePrompt, "Thirty entries in one day isn't a habit yet")
        let state = EditorState(); state.store = store
        state.spent = false
        state.amount = "50"
        state.label = "Sam owes me"
        state.awaiting = true
        XCTAssertTrue(state.save())
        XCTAssertFalse(store.showSharePrompt, "Expecting money isn't the moment; receiving it is")
        XCTAssertTrue(store.settle(try XCTUnwrap(store.waiting.first), cents: 5_000, on: .today))
        XCTAssertTrue(store.showSharePrompt)
        store.dismissSharePrompt()
        XCTAssertFalse(store.showSharePrompt)
        XCTAssertEqual(store.sharePrompt, "done")
    }

    func testPayingABillDoesNotAskToShare() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 50_000, openAtLogin: false))
        let state = EditorState(); state.store = store
        state.spent = true
        state.amount = "20"
        state.label = "Electric bill"
        state.awaiting = true
        XCTAssertTrue(state.save())
        XCTAssertTrue(store.settle(try XCTUnwrap(store.waiting.first), cents: -2_000, on: .today))
        XCTAssertFalse(store.showSharePrompt)
    }

    func testWaitingOptionOnlyAppliesToOneTimeEntriesDueByToday() {
        let state = EditorState()
        state.awaiting = true
        state.frequency = .monthly
        XCTAssertFalse(state.waitsNow)
        state.frequency = .once
        state.date = Date().addingTimeInterval(3 * 86_400)
        XCTAssertFalse(state.waitsNow, "A future date already waits as a planned payment")
        state.reset()
        XCTAssertFalse(state.awaiting)
    }

    func testEntryBecomesAQuickAddButtonOnce() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 10_000, openAtLogin: false))
        let id = try XCTUnwrap(store.addEntry(cents: -450, label: "Coffee", day: .today, category: "food"))
        let start = try XCTUnwrap(store.ledger.entries.first { $0.category == Categories.start })
        XCTAssertFalse(store.canSaveAsPreset(start), "The starting balance isn't a purchase")
        XCTAssertTrue(store.saveAsPreset(id))
        XCTAssertEqual(store.ledger.presets, [Preset(id: store.ledger.presets[0].id, label: "Coffee", cents: 450, sign: -1, category: "food")])
        XCTAssertEqual(store.balance, 9_550, "Making a button doesn't log another purchase")
        XCTAssertEqual(store.receipt?.target, .section(.settings))
        XCTAssertTrue(store.receipt?.text.contains("⌘1") ?? false)
        let again = try XCTUnwrap(store.addEntry(cents: -450, label: "coffee", day: .today, category: "food"))
        XCTAssertFalse(store.saveAsPreset(again))
        XCTAssertEqual(store.ledger.presets.count, 1)
    }

    func testQuickAddMenuLogsFixedAmountsAndAsksForTheRest() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 10_000, openAtLogin: false))
        let lunch = Preset(label: "Lunch", cents: 1_200, sign: -1, category: "food")
        let groceries = Preset(label: "Groceries", cents: nil, sign: -1, category: "food")
        XCTAssertTrue(store.savePreset(lunch))
        XCTAssertTrue(store.savePreset(groceries))
        store.useQuickAdd(lunch)
        XCTAssertEqual(store.balance, 8_800)
        XCTAssertNil(store.windowRequest)
        store.useQuickAdd(groceries)
        XCTAssertEqual(store.balance, 8_800)
        XCTAssertEqual(store.windowRequest, .quickAdd(groceries))
    }

    func testIncomeIsBrokenDownByCategoryToo() {
        let day = Day(iso: "2026-10-05")!
        var l = Ledger()
        l.add(Entry(cents: 20_000, label: "Start", day: day, category: Categories.start))
        l.add(Entry(cents: 75_000, label: "Client A", day: day, category: "pay"))
        l.add(Entry(cents: 2_500, label: "Refund", day: day, category: "refund"))
        l.add(Entry(cents: 1_000, label: "Found", day: day))
        l.add(Entry(cents: -500, label: "Snack", day: day))
        let s = l.summary(day.yearMonth)
        XCTAssertEqual(s.incomeByCategory.map(\.category), ["pay", "refund", Categories.uncategorized])
        XCTAssertEqual(s.incomeByCategory.map(\.cents).reduce(0, +), s.income)
        XCTAssertEqual(s.byCategory.map(\.category), [Categories.uncategorized])
    }

    func testDailyBackupCanBeRestored() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 10_000, openAtLogin: false))
        let folder = store.fileURL.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let older = Ledger(currency: "USD", entries: [Entry(cents: 42_000, label: "Starting balance", day: Day(iso: "2026-10-01")!,
                                                            category: Categories.start)])
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(older).write(to: folder.appendingPathComponent("ledger-2026-10-01.json"))
        try Data("not a backup".utf8).write(to: folder.appendingPathComponent("notes.txt"))
        _ = store.addEntry(cents: -100, label: "Gum", day: .today, category: nil)

        XCTAssertEqual(store.backups.map(\.day), [.today, Day(iso: "2026-10-01")!], "Newest first, other files ignored")
        try store.restore(try XCTUnwrap(store.backups.last))
        XCTAssertEqual(store.balance, 42_000)
        XCTAssertNil(store.saveError)
    }

    func testRestoringOverUnreadableDataKeepsTheUnreadableFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pocket-features-\(UUID())")
        let store = try isolatedStore(directory: directory)
        XCTAssertTrue(store.start(currency: "USD", cents: 10_000, openAtLogin: false))
        _ = store.addEntry(cents: -100, label: "Gum", day: .today, category: nil)
        let damaged = Data("damaged JSON".utf8)
        try damaged.write(to: store.fileURL)

        let reopened = try isolatedStore(directory: directory)
        XCTAssertNotNil(reopened.loadError)
        let backup = try XCTUnwrap(reopened.backups.first)
        try reopened.restore(backup)
        XCTAssertNil(reopened.loadError)
        XCTAssertEqual(reopened.balance, 10_000, "Today's backup was made before the first change of the day")

        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        let setAside = try XCTUnwrap(files.first { $0.hasPrefix("ledger (couldn't open)") })
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(setAside)), damaged)
        for b in reopened.backups { XCTAssertNotEqual(try Data(contentsOf: b.url), damaged, "The damaged file never becomes a backup") }
    }
}
