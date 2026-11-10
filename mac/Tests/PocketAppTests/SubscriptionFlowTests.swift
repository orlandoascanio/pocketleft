import AppKit
import PocketCore
import SwiftUI
import XCTest
@testable import Pocket

@MainActor
final class SubscriptionFlowTests: XCTestCase {
    private func store() throws -> Store {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pocket-subscription-\(UUID())")
        let suite = "pocket-subscription-tests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(false, forKey: "reminders")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        return Store(directory: directory, defaults: defaults, servicesEnabled: false)
    }

    func testIncludingExistingPaymentNeverDuplicatesItOrChangesItsCategory() throws {
        let store = try store()
        let rule = Rule(cents: -999, label: "Cloud", cadence: .monthly, anchor: Day.today.adding(days: 2), category: "apps")
        XCTAssertTrue(store.addRule(rule))
        let balance = store.balance
        XCTAssertTrue(store.setSubscription(rule.id, true))
        XCTAssertEqual(store.ledger.rules.count, 1)
        XCTAssertEqual(store.balance, balance)
        XCTAssertTrue(store.ledger.rules[0].isSubscription)
        XCTAssertEqual(store.ledger.rules[0].category, "apps")
        XCTAssertTrue(store.setSubscription(rule.id, false))
        XCTAssertEqual(store.ledger.rules.count, 1)
        XCTAssertFalse(store.ledger.rules[0].isSubscription)
        XCTAssertEqual(store.ledger.rules[0].category, "apps")
    }

    func testNewSubscriptionUsesExistingEditorAndRoundTripsOnDisk() throws {
        let store = try store()
        let state = EditorState(); state.store = store
        state.startSubscription()
        state.label = "Cloud"
        state.category = "apps"
        state.amount = "9.99"
        state.date = Day.today.adding(days: 2).localDate
        XCTAssertTrue(state.save())
        XCTAssertEqual(store.ledger.rules.count, 1)
        XCTAssertEqual(store.ledger.entries.count, 0)
        let rule = try XCTUnwrap(store.ledger.rules.first)
        XCTAssertTrue(rule.isSubscription)
        XCTAssertEqual(rule.category, "apps")
        let reopened = Store(directory: store.fileURL.deletingLastPathComponent(), servicesEnabled: false)
        XCTAssertTrue(try XCTUnwrap(reopened.ledger.rules.first).isSubscription)
        state.load(rule)
        state.amount = "12.99"
        XCTAssertTrue(state.save())
        XCTAssertEqual(store.ledger.rules.count, 1)
        XCTAssertTrue(store.ledger.rules[0].isSubscription)
        XCTAssertEqual(store.ledger.rules[0].category, "apps")
    }

    func testPausedSubscriptionsLeaveTotalsAndForecastAndCanResume() throws {
        let store = try store()
        let rule = Rule(cents: -999, label: "Cloud", cadence: .monthly, anchor: Day.today.adding(days: 2), subscription: true)
        XCTAssertTrue(store.addRule(rule))
        XCTAssertTrue(store.setActive(rule.id, false))
        let summary = SubscriptionSummary(ledger: store.ledger, today: store.today)
        XCTAssertEqual(summary.monthly, 0)
        XCTAssertEqual(summary.paused.count, 1)
        XCTAssertTrue(store.projection.steps.isEmpty)
        XCTAssertTrue(store.setActive(rule.id, true))
        XCTAssertEqual(SubscriptionSummary(ledger: store.ledger, today: store.today).monthly, 999)
    }

    func testFailedMembershipWriteLeavesSavedPaymentUnchanged() throws {
        let store = try store()
        let rule = Rule(cents: -999, label: "Cloud", cadence: .monthly, anchor: Day.today.adding(days: 2), category: "apps")
        XCTAssertTrue(store.addRule(rule))
        let backup = store.fileURL.appendingPathExtension("saved")
        try FileManager.default.moveItem(at: store.fileURL, to: backup)
        try FileManager.default.createDirectory(at: store.fileURL, withIntermediateDirectories: false)
        XCTAssertFalse(store.setSubscription(rule.id, true))
        XCTAssertFalse(store.ledger.rules[0].isSubscription)
        XCTAssertNotNil(store.saveError)
    }

    func testRenderSubscriptions() throws {
        guard let path = ProcessInfo.processInfo.environment["POCKET_SUBSCRIPTIONS_SNAPSHOTS"] else { throw XCTSkip("Opt-in native renders") }
        _ = NSApplication.shared
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        let store = try store()
        XCTAssertTrue(store.start(currency: "USD", cents: 240000, openAtLogin: false))
        let fixtures: [(String, Int, Cadence, Int, String, Bool)] = [
            ("Netflix", 1549, .monthly, 2, "subscriptions", true),
            ("iCloud+", 299, .monthly, 4, "apps", true),
            ("Spotify", 1199, .monthly, 8, "fun", true),
            ("Adobe Creative Cloud", 5999, .monthly, 13, "apps", true),
            ("Domain renewal", 1800, .yearly, 22, "apps", true),
            ("Gym", 3500, .monthly, 3, "fun", false),
        ]
        for (label, cents, cadence, days, category, active) in fixtures {
            XCTAssertTrue(store.addRule(Rule(cents: -cents, label: label, cadence: cadence, anchor: store.today.adding(days: days),
                                            active: active, category: category, subscription: true)))
        }
        XCTAssertTrue(store.addRule(Rule(cents: -85000, label: "Rent", cadence: .monthly, anchor: store.today.adding(days: 5), category: "bills")))
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            NSApp.appearance = NSAppearance(named: appearance)
            try capture(SubscriptionsView(onEdit: { _ in }).environmentObject(store), size: NSSize(width: 800, height: 1080), path: path + "/subscriptions-\(name).png")
            try capture(SubscriptionsView(onEdit: { _ in }).environmentObject(store), size: NSSize(width: 580, height: 560), path: path + "/subscriptions-minimum-\(name).png")
            store.windowRequest = .section(.subscriptions)
            try capture(MainWindow().environmentObject(store), size: NSSize(width: 1000, height: 780), path: path + "/subscriptions-window-\(name).png")
        }
        let empty = try self.store()
        NSApp.appearance = NSAppearance(named: .aqua)
        try capture(SubscriptionsView(onEdit: { _ in }).environmentObject(empty), size: NSSize(width: 580, height: 560), path: path + "/subscriptions-empty.png")
        store.windowRequest = .section(.subscriptions)
        try capture(MainWindow().environmentObject(store), size: NSSize(width: 1000, height: 780), path: path + "/subscriptions-window.png")
        try store.export(to: URL(fileURLWithPath: path + "/demo-ledger.json"))
    }

    private func capture<V: View>(_ view: V, size: NSSize, path: String) throws {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        window.orderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        window.contentView = nil
        window.close()
    }
}
