import AppKit
import Foundation
import PocketCore
import SwiftUI
import XCTest
@testable import Pocket

/// Trying a purchase before planning it, and catching up from a bank statement with an undo for the whole import.
@MainActor
final class WhatIfAndImportFlowTests: XCTestCase {
    private var directory: URL!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("pocket-whatif-\(UUID())")
        let suite = "pocket-whatif-\(UUID())"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(false, forKey: "reminders")
        let dir = directory!
        addTeardownBlock {
            try? FileManager.default.removeItem(at: dir)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
    }

    private func makeStore(connected session: Bool = false) -> Store {
        guard session else { return Store(directory: directory, defaults: defaults, servicesEnabled: false) }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockAccount.self]
        return Store(directory: directory, defaults: defaults, servicesEnabled: false,
                     session: URLSession(configuration: config), keyStore: .memory())
    }

    private func statement(_ store: Store) throws -> [StatementRow] {
        let d = { (n: Int) in store.today.adding(days: -n).iso }
        let csv = """
        Date,Description,Amount
        \(d(6)),Bakery,-3.20
        \(d(5)),Bus pass,-25.00
        \(d(4)),Refund from shop,12.00
        """
        return try StatementImport.preview(csv, ledger: store.ledger, today: store.today).rows
    }

    func testTryingAPurchaseSavesNothingUntilItIsPlanned() throws {
        let store = makeStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 50_000, openAtLogin: false))
        let later = PurchaseIdea(cents: 20_000, day: store.today.adding(days: 2))
        _ = store.ledger.checkPurchase(later, today: store.today, days: store.range, everyday: 0)
        XCTAssertTrue(store.ledger.rules.isEmpty)

        XCTAssertTrue(store.planPurchase(later, label: "Boots"))
        let rule = try XCTUnwrap(store.ledger.rules.first)
        XCTAssertEqual(rule.cents, -20_000)
        XCTAssertTrue(rule.isOnce)
        XCTAssertEqual(rule.next, later.day)
        XCTAssertEqual(store.balance, 50_000, "A planned expense counts on its day")

        XCTAssertTrue(store.planPurchase(PurchaseIdea(cents: 1_500, day: store.today), label: "Lunch"))
        XCTAssertEqual(store.balance, 48_500, "Going ahead today is spending today")
        XCTAssertEqual(store.ledger.rules.count, 1)
    }

    func testStatementImportCanBeUndoneAsAWhole() throws {
        let store = makeStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 50_000, openAtLogin: false))
        let rows = try statement(store)
        XCTAssertNotNil(store.importStatement(rows, fileName: "bank.csv"))
        XCTAssertEqual(store.balance, 50_000 - 320 - 2_500 + 1_200)
        let batch = try XCTUnwrap(store.lastStatementImport)
        XCTAssertEqual(store.remainingEntries(batch).count, 3)

        // Edits and deletions after the import, plus something recorded by hand.
        var bakery = try XCTUnwrap(store.ledger.entries.first { $0.label == "Bakery" })
        bakery.label = "Bakery (croissant)"
        XCTAssertTrue(store.updateEntry(bakery))
        XCTAssertTrue(store.deleteEntry(try XCTUnwrap(store.ledger.entries.first { $0.label == "Bus pass" }).id))
        XCTAssertNotNil(store.addEntry(cents: -900, label: "Dinner", day: store.today, category: "food"))

        let reopened = makeStore()
        XCTAssertEqual(reopened.lastStatementImport, batch, "The undo survives quitting")
        XCTAssertNil(reopened.undoStatementImport(batch))
        XCTAssertEqual(reopened.balance, 50_000 - 900)
        XCTAssertEqual(reopened.ledger.entries.map(\.label).sorted(), ["Dinner", "Starting balance"])
        XCTAssertNil(reopened.lastStatementImport)

        let rows2 = try statement(reopened)
        XCTAssertTrue(rows2.allSatisfy { $0.duplicate == nil }, "Undone rows aren't duplicates anymore")
    }

    func testImportedEntriesReachTheAccountAndUndoRemovesThemThere() async throws {
        MockAccount.reset(balance: 100)
        let store = makeStore(connected: true)
        try await store.connect(key: MockAccount.key)
        await store.syncNow()
        XCTAssertNotNil(store.importStatement(try statement(store), fileName: "bank.csv"))
        await store.syncNow()
        XCTAssertEqual(MockAccount.serverBalance, 10_000 - 320 - 2_500 + 1_200)
        XCTAssertEqual(store.balance, MockAccount.serverBalance)
        let batch = try XCTUnwrap(store.lastStatementImport, "Still undoable after the account renamed the ids")
        XCTAssertEqual(store.remainingEntries(batch).count, 3)

        XCTAssertNil(store.undoStatementImport(batch))
        await store.syncNow()
        XCTAssertEqual(MockAccount.serverBalance, 10_000)
        XCTAssertEqual(store.balance, 10_000)
        XCTAssertTrue(store.outbox.isEmpty)
    }

    func testUndoBeforeTheImportIsSentSendsNothing() async throws {
        MockAccount.reset(balance: 100)
        let store = makeStore(connected: true)
        try await store.connect(key: MockAccount.key)
        await store.syncNow()
        MockAccount.failure = .notConnectedToInternet
        XCTAssertNotNil(store.importStatement(try statement(store), fileName: "bank.csv"))
        await store.syncNow()
        XCTAssertEqual(store.outbox.count, 3)
        XCTAssertNil(store.undoStatementImport(try XCTUnwrap(store.lastStatementImport)))
        XCTAssertTrue(store.outbox.isEmpty, "Adds that never left are simply dropped")
        MockAccount.failure = nil
        MockAccount.calls = []
        await store.syncNow()
        XCTAssertFalse(MockAccount.calls.contains("pocket_add"))
        XCTAssertFalse(MockAccount.calls.contains("pocket_delete"))
        XCTAssertEqual(store.balance, 10_000)
    }
}

/// Opt-in native renders of the new Plan card and the statement preview: POCKET_WHATIF_SNAPSHOTS=/some/dir swift test
@MainActor
final class WhatIfRenderTests: XCTestCase {
    func testRenderTryAPurchaseAndStatementPreview() throws {
        guard let path = ProcessInfo.processInfo.environment["POCKET_WHATIF_SNAPSHOTS"] else { throw XCTSkip("Opt-in native renders") }
        _ = NSApplication.shared
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pocket-render-\(UUID())")
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "pocket-render-\(UUID())"))
        defaults.set(false, forKey: "reminders")
        let store = Store(directory: directory, defaults: defaults, servicesEnabled: false)
        XCTAssertTrue(store.start(currency: "USD", cents: 100_000, openAtLogin: false))
        let thursday = store.today.adding(days: 3)
        XCTAssertTrue(store.addRule(Rule(cents: -80_000, label: "Rent", cadence: .monthly, anchor: thursday, category: "bills")))
        XCTAssertTrue(store.addRule(Rule(cents: 150_000, label: "Paycheck", cadence: .biweekly, anchor: thursday.adding(days: 1), category: "pay")))
        XCTAssertNotNil(store.addEntry(cents: -450, label: "Coffee", day: store.today.adding(days: -2), category: "food"))
        let d = { (n: Int) in store.today.adding(days: -n).iso }
        let csv = "Date,Description,Amount\n\(d(6)),BAKERY ON MAIN,-3.20\n\(d(2)),COFFEE ROASTERS #12,-4.50\n\(d(5)),CITY TRANSIT PASS,-25.00\n\(d(4)),REFUND - BOOKSHOP,12.00\n\(d(3)),GROCERY MARKET,-61.38\n\(d(3)),GROCERY MARKET,-61.38\n"
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            NSApp.appearance = NSAppearance(named: appearance)
            try capture(TryPurchaseCard(text: "$200 on \(thursday.adding(days: -1).localDate.formatted(.dateTime.weekday(.wide)))")
                .environmentObject(store).padding(20).frame(width: 640), size: NSSize(width: 640, height: 330), path: path + "/try-\(name).png")
            try capture(TryPurchaseCard(text: "$300 on \(thursday.adding(days: -1).localDate.formatted(.dateTime.weekday(.wide))) for boots")
                .environmentObject(store).padding(20).frame(width: 640), size: NSSize(width: 640, height: 330), path: path + "/try-short-\(name).png")
            try capture(StatementImportSheet(file: StatementFile(name: "checking.csv", text: csv), onDone: { _ in }).environmentObject(store),
                        size: NSSize(width: 660, height: 600), path: path + "/import-\(name).png")
            try capture(PlanView(onEdit: { _ in }).environmentObject(store), size: NSSize(width: 820, height: 900), path: path + "/plan-\(name).png")
        }
    }

    private func capture<V: View>(_ view: V, size: NSSize, path: String) throws {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        window.orderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        window.contentView = nil
        window.close()
    }
}
