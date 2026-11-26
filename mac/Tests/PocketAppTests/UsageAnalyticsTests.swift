import Foundation
import PocketCore
import XCTest
@testable import Pocket

/// Collects what UsageAnalytics would send, instead of reaching PostHog.
private final class Outbox: @unchecked Sendable {
    private let lock = NSLock()
    private var bodies: [[String: Any]] = []

    var transport: UsageAnalytics.Transport {
        { [self] request in
            guard let data = request.httpBody,
                  let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
            lock.withLock { bodies.append(body) }
        }
    }

    var sent: [[String: Any]] { lock.withLock { bodies } }
    var events: [String] { sent.compactMap { $0["event"] as? String } }

    /// Sends run on a background task; wait until the expected count arrives.
    func wait(for count: Int, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while sent.count < count && Date() < deadline { try? await Task.sleep(for: .milliseconds(10)) }
    }
}

@MainActor
final class UsageAnalyticsTests: XCTestCase {
    private func isolatedStore(_ outbox: Outbox, defaults existing: UserDefaults? = nil) throws -> (Store, UserDefaults) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pocket-usage-\(UUID())")
        let suite = "pocket-usage-tests-\(UUID())"
        let defaults = try existing ?? XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(false, forKey: "reminders")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        let store = Store(directory: directory, defaults: defaults, servicesEnabled: false, usageTransport: outbox.transport)
        return (store, defaults)
    }

    func testOnByDefaultFromFirstLaunch() async throws {
        let outbox = Outbox()
        let (store, defaults) = try isolatedStore(outbox)
        XCTAssertTrue(store.shareUsageData)
        XCTAssertNotNil(defaults.string(forKey: "usageAnalyticsID"))
        await outbox.wait(for: 2)
        XCTAssertEqual(outbox.events.sorted(), ["app_active", "app_first_seen"])
    }

    func testEventsCarryNoMoneyData() async throws {
        let outbox = Outbox()
        let (store, _) = try isolatedStore(outbox)
        XCTAssertTrue(store.start(currency: "EUR", cents: 98_765, openAtLogin: false))
        store.addEntry(cents: -4_321, label: "Secret dinner", day: store.today, category: "food")
        XCTAssertTrue(store.addRule(Rule(cents: -1_999, label: "Gym membership", cadence: .monthly, anchor: store.today.adding(days: 3))))
        await outbox.wait(for: 4)

        XCTAssertEqual(Set(outbox.events), ["app_first_seen", "app_active", "entry_added", "payment_scheduled"])
        let allowed: Set<String> = ["$lib", "$process_person_profile", "$geoip_disable", "app_version", "os_version", "language"]
        for body in outbox.sent {
            XCTAssertEqual(Set(body.keys), ["api_key", "event", "distinct_id", "properties", "timestamp"])
            let properties = try XCTUnwrap(body["properties"] as? [String: Any])
            XCTAssertTrue(Set(properties.keys).isSubset(of: allowed), "Unexpected properties: \(properties.keys)")
            XCTAssertEqual(properties["$process_person_profile"] as? Bool, false)
            let text = String(data: try JSONSerialization.data(withJSONObject: body), encoding: .utf8) ?? ""
            for secret in ["Secret dinner", "Gym membership", "food", "EUR", "43.21", "4321", "987.65", "98765", "19.99"] {
                XCTAssertFalse(text.contains(secret), "\(secret) leaked into \(body["event"] ?? "")")
            }
        }
        XCTAssertEqual(Set(outbox.sent.compactMap { $0["distinct_id"] as? String }).count, 1)
    }

    func testTurningOffDeletesTheIDAndStopsSending() async throws {
        let outbox = Outbox()
        let (store, defaults) = try isolatedStore(outbox)
        await outbox.wait(for: 2)
        let firstID = try XCTUnwrap(defaults.string(forKey: "usageAnalyticsID"))

        store.shareUsageData = false
        XCTAssertNil(defaults.string(forKey: "usageAnalyticsID"))
        store.addEntry(cents: -500, label: "Coffee", day: store.today, category: nil)
        store.tick()
        await outbox.wait(for: 3, timeout: 0.3)
        XCTAssertEqual(outbox.sent.count, 2, "Nothing more is sent once it's off")

        // The choice survives a relaunch.
        let (relaunched, _) = try isolatedStore(outbox, defaults: defaults)
        XCTAssertFalse(relaunched.shareUsageData)
        XCTAssertNil(defaults.string(forKey: "usageAnalyticsID"))

        relaunched.shareUsageData = true
        await outbox.wait(for: 3)
        XCTAssertEqual(outbox.events.last, "app_first_seen")
        XCTAssertNotEqual(defaults.string(forKey: "usageAnalyticsID"), firstID, "Turning it back on starts a new random ID")
    }

    func testActiveDayCountsOncePerDayAndNoticesUpdates() async throws {
        let outbox = Outbox()
        let suite = "pocket-usage-direct-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let old = UsageAnalytics(defaults: defaults, transport: outbox.transport, version: "1.5.4")
        old.recordActive(on: "2026-11-26")
        old.recordActive(on: "2026-11-26")
        await outbox.wait(for: 2)
        // Sends run in parallel, so arrival order isn't fixed; each event carries its own timestamp.
        XCTAssertEqual(outbox.events.sorted(), ["app_active", "app_first_seen"])

        let new = UsageAnalytics(defaults: defaults, transport: outbox.transport, version: "1.5.5")
        new.recordActive(on: "2026-11-27")
        await outbox.wait(for: 4)
        XCTAssertEqual(outbox.events.sorted(), ["app_active", "app_active", "app_first_seen", "app_updated"])
        let update = try XCTUnwrap(outbox.sent.first { $0["event"] as? String == "app_updated" })
        let properties = try XCTUnwrap(update["properties"] as? [String: Any])
        XCTAssertEqual(properties["previous_version"] as? String, "1.5.4")
        XCTAssertEqual(properties["app_version"] as? String, "1.5.5")
    }

    func testStoresWithoutATransportNeverSend() {
        let suite = "pocket-usage-silent-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let usage = UsageAnalytics(defaults: defaults, transport: nil)
        XCTAssertTrue(usage.enabled, "On by default even where sending is disabled")
        usage.recordActive(on: "2026-11-26")
        usage.capture(.entryAdded) // Must not crash or send.
    }
}
