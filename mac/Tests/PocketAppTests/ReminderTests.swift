import Foundation
import PocketCore
import UserNotifications
import XCTest
@testable import Pocket

@MainActor
final class ReminderTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    private let dueDay = Day(iso: "2026-10-13")!
    /// Fixture payments were added days before they came due.
    private let addedEarlier = ISO8601DateFormatter().date(from: "2026-10-01T12:00:00Z")!

    private func localDate(hour: Int, on day: Day = Day(iso: "2026-10-13")!) -> Date {
        Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour))!
    }

    private func fixture(_ backend: FakeReminderClient, clock: ReminderClock) throws -> (Store, URL, UserDefaults) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pocket-reminders-\(UUID())")
        let suite = "pocket-reminders-tests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(true, forKey: "reminders")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        return (Store(directory: directory, defaults: defaults, servicesEnabled: false,
                      reminderClient: backend.client, reminderNow: { clock.now }), directory, defaults)
    }

    func testDueDayRefreshKeepsTodaysReminderBeforeTen() {
        let rule = Rule(cents: 45000, label: "Client", cadence: .monthly,
                        anchor: Day(iso: "2026-10-13")!, auto: false, created: addedEarlier)
        let plans = PaymentReminders.plans(for: [rule], now: date("2026-10-13T09:00:00Z"), calendar: calendar)
        XCTAssertEqual(plans.count, 1, "Refreshing on the due date must retain the reminder scheduled for 10 AM.")
        XCTAssertEqual(plans.first?.date, date("2026-10-13T10:00:00Z"))
    }

    func testSubscriptionWarningsAreOptInAndPrecedeAutomaticCharges() {
        let rule = Rule(cents: -1500, label: "Music", cadence: .monthly, anchor: dueDay, auto: true, subscription: true)
        let now = date("2026-10-11T09:00:00Z")
        XCTAssertTrue(PaymentReminders.plans(for: [rule], now: now, calendar: calendar).isEmpty)
        let plans = PaymentReminders.plans(for: [rule], now: now, calendar: calendar, payments: false, subscriptions: true)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.date, date("2026-10-12T10:00:00Z"))
        XCTAssertEqual(plans.first?.title, "Music renews tomorrow")
        XCTAssertEqual(plans.first?.content.userInfo["subscriptions"] as? Bool, true)
        XCTAssertFalse(plans.first?.catchUp ?? true)
        var paused = rule; paused.active = false
        XCTAssertTrue(PaymentReminders.plans(for: [paused], now: now, calendar: calendar, subscriptions: true).isEmpty)
    }

    func testSubscriptionWarningRetainsDueDayRequestWithoutLateCatchUp() async throws {
        let backend = FakeReminderClient()
        let clock = ReminderClock(localDate(hour: 9, on: dueDay.adding(days: -1)))
        let (store, _, _) = try fixture(backend, clock: clock)
        store.reminders = false
        store.subscriptionReminders = true
        let rule = Rule(cents: -1500, label: "Music", cadence: .monthly, anchor: dueDay, auto: false, subscription: true)
        XCTAssertTrue(store.addRule(rule))
        await store.refreshReminders()
        XCTAssertEqual(backend.requests.count, 1)
        let id = try XCTUnwrap(backend.requests.keys.first)
        clock.now = localDate(hour: 11, on: dueDay.adding(days: -1))
        await store.refreshReminders()
        XCTAssertNotNil(backend.requests[id])
        backend.requests.removeAll()
        await store.refreshReminders()
        XCTAssertEqual(backend.added.count, 1, "Do not send a late renewal warning after delivery")
        store.subscriptionReminders = false
        await store.refreshReminders()
        XCTAssertTrue(backend.requests.isEmpty)
    }

    func testTenAMUsesLocalTimeAcrossDaylightSavingTransition() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let rule = Rule(cents: -2500, label: "Phone", cadence: .monthly,
                        anchor: Day(iso: "2026-03-08")!, auto: false, created: date("2026-03-01T12:00:00Z"))
        let plan = PaymentReminders.plans(for: [rule], now: date("2026-03-08T06:30:00Z"), calendar: calendar)
        XCTAssertEqual(plan.first?.date, date("2026-03-08T14:00:00Z"))
        XCTAssertEqual(plan.first?.title, "Was Phone paid?")
    }

    func testPaymentAddedAfterItsReminderTimeIsNotRemindedRightAway() {
        let late = Rule(cents: 5000, label: "Sam", cadence: .monthly, anchor: dueDay, total: 1, auto: false,
                        created: date("2026-10-13T15:00:00Z"))
        let earlier = Rule(cents: 45000, label: "Client", cadence: .monthly, anchor: dueDay, auto: false, created: addedEarlier)
        let plans = PaymentReminders.plans(for: [late, earlier], now: date("2026-10-13T15:00:05Z"), calendar: calendar)
        XCTAssertEqual(plans.map(\.title), ["Did Client pay?"], "Marking money as still waiting shouldn't notify about it seconds later.")
        let tomorrow = Rule(cents: 5000, label: "Sam", cadence: .monthly, anchor: dueDay.adding(days: 1), total: 1, auto: false,
                            created: date("2026-10-13T15:00:00Z"))
        XCTAssertEqual(PaymentReminders.plans(for: [tomorrow], now: date("2026-10-13T15:00:05Z"), calendar: calendar).count, 1)
    }

    func testOnlyActiveUnfinishedConfirmationPaymentsAreScheduled() {
        let valid = Rule(cents: 45000, label: "Client", cadence: .monthly, anchor: dueDay, auto: false, created: addedEarlier)
        var paused = valid; paused.active = false
        var automatic = valid; automatic.auto = true
        var finished = valid; finished.total = 1; finished.posted = 1
        var overdue = valid; overdue.anchor = dueDay.adding(days: -1)
        let plans = PaymentReminders.plans(for: [paused, automatic, finished, overdue, valid],
                                          now: date("2026-10-13T09:00:00Z"), calendar: calendar)
        XCTAssertEqual(plans.map(\.title), ["Did Client pay?"])
    }

    func testOvernightRefreshPreservesTheSameQueuedDueDayRequest() async throws {
        let backend = FakeReminderClient()
        let clock = ReminderClock(localDate(hour: 23, on: dueDay.adding(days: -1)))
        let (store, _, _) = try fixture(backend, clock: clock)
        let rule = Rule(cents: 45000, label: "Client", cadence: .monthly, anchor: dueDay, auto: false, created: addedEarlier)
        XCTAssertTrue(store.addRule(rule))
        await store.refreshReminders()
        let request = try XCTUnwrap(backend.requests.values.first)
        XCTAssertTrue(request.trigger is UNCalendarNotificationTrigger)
        clock.now = localDate(hour: 9)
        await store.refreshReminders()
        XCTAssertNotNil(backend.requests[request.identifier])
        XCTAssertEqual(backend.added.count, 1)
        XCTAssertFalse(backend.removed.contains(request.identifier))
        clock.now = localDate(hour: 11)
        await store.refreshReminders()
        XCTAssertNotNil(backend.requests[request.identifier], "Don't cancel a due-day request while macOS is delivering it.")
    }

    func testLateLaunchCatchesUpOnceEvenAfterDeliveryDismissalAndRestart() async throws {
        let backend = FakeReminderClient()
        let clock = ReminderClock(localDate(hour: 11))
        let (store, directory, defaults) = try fixture(backend, clock: clock)
        XCTAssertTrue(store.addRule(Rule(cents: 45000, label: "Client", cadence: .monthly, anchor: dueDay, auto: false, created: addedEarlier)))
        await store.refreshReminders()
        XCTAssertEqual(backend.added.count, 1)
        let request = try XCTUnwrap(backend.requests.values.first)
        XCTAssertEqual((request.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval, 5)
        backend.requests.removeAll() // macOS delivered it; the user dismissed the banner.
        await store.refreshReminders()
        XCTAssertEqual(backend.added.count, 1)
        let reopened = Store(directory: directory, defaults: defaults, servicesEnabled: false,
                             reminderClient: backend.client, reminderNow: { clock.now })
        await reopened.refreshReminders()
        XCTAssertEqual(backend.added.count, 1)
    }

    func testNormalTenAMDeliveryDoesNotBecomeADuplicateCatchUp() async throws {
        let backend = FakeReminderClient()
        let clock = ReminderClock(localDate(hour: 9))
        let (store, _, _) = try fixture(backend, clock: clock)
        XCTAssertTrue(store.addRule(Rule(cents: 45000, label: "Client", cadence: .monthly, anchor: dueDay, auto: false, created: addedEarlier)))
        await store.refreshReminders()
        backend.requests.removeAll()
        clock.now = localDate(hour: 11)
        await store.refreshReminders()
        XCTAssertEqual(backend.added.count, 1)
    }

    func testTurningOffAndPausingCancelQueuedReminders() async throws {
        let backend = FakeReminderClient()
        let clock = ReminderClock(localDate(hour: 9))
        let (store, _, _) = try fixture(backend, clock: clock)
        let rule = Rule(cents: 45000, label: "Client", cadence: .monthly, anchor: dueDay, auto: false, created: addedEarlier)
        XCTAssertTrue(store.addRule(rule))
        await store.refreshReminders()
        XCTAssertTrue(store.setActive(rule.id, false))
        await store.refreshReminders()
        XCTAssertTrue(backend.requests.isEmpty)
        XCTAssertTrue(store.setActive(rule.id, true))
        await store.refreshReminders()
        XCTAssertEqual(backend.requests.count, 1)
        await store.sendTestReminder()
        XCTAssertNotNil(backend.requests[PaymentReminders.testIdentifier])
        store.reminders = false
        await store.refreshReminders()
        XCTAssertTrue(backend.requests.isEmpty)
    }

    func testDeniedPermissionIsVisibleAndDoesNotClaimTestReminderWasSent() async throws {
        let backend = FakeReminderClient()
        backend.status = .denied
        let (store, _, _) = try fixture(backend, clock: ReminderClock(localDate(hour: 9)))
        await store.sendTestReminder()
        await store.refreshReminders()
        XCTAssertTrue(backend.added.isEmpty)
        XCTAssertEqual(backend.permissionRequests, 0)
        XCTAssertTrue(store.reminderMessage?.contains("System Settings") == true)
    }

    func testTestReminderRequestsPermissionUsesFiveSecondsAndLeavesLedgerAlone() async throws {
        let backend = FakeReminderClient()
        backend.status = .notDetermined
        let (store, _, _) = try fixture(backend, clock: ReminderClock(localDate(hour: 9)))
        let original = store.ledger
        await store.sendTestReminder()
        await store.refreshReminders()
        XCTAssertEqual(backend.permissionRequests, 1)
        let request = try XCTUnwrap(backend.requests[PaymentReminders.testIdentifier])
        XCTAssertEqual((request.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval, 5)
        XCTAssertEqual(store.ledger, original)
        XCTAssertFalse(store.sendingTestReminder)
        XCTAssertFalse(backend.removed.contains(PaymentReminders.testIdentifier))
    }

    func testFailedSchedulingReportsErrorAndCanRetryWithoutSuppression() async throws {
        let backend = FakeReminderClient()
        backend.failAdds = true
        let (store, _, _) = try fixture(backend, clock: ReminderClock(localDate(hour: 11)))
        XCTAssertTrue(store.addRule(Rule(cents: 45000, label: "Client", cadence: .monthly, anchor: dueDay, auto: false, created: addedEarlier)))
        await store.refreshReminders()
        XCTAssertTrue(backend.requests.isEmpty)
        XCTAssertTrue(store.reminderMessage?.contains("Couldn't schedule") == true)
        backend.failAdds = false
        await store.refreshReminders()
        XCTAssertEqual(backend.requests.count, 1)
        XCTAssertNil(store.reminderMessage)
        backend.requests.removeAll()
        await store.refreshReminders()
        XCTAssertEqual(backend.added.count, 1)
    }

    func testEditDuringRefreshCannotScheduleAnObsoletePayment() async throws {
        let backend = FakeReminderClient()
        let (store, _, _) = try fixture(backend, clock: ReminderClock(localDate(hour: 9)))
        await store.refreshReminders()
        backend.blockNextPending = true
        let rule = Rule(cents: 45000, label: "Client", cadence: .monthly, anchor: dueDay, auto: false, created: addedEarlier)
        XCTAssertTrue(store.addRule(rule))
        for _ in 0..<100 {
            if backend.pendingContinuation != nil { break }
            await Task.yield()
        }
        XCTAssertNotNil(backend.pendingContinuation)
        XCTAssertTrue(store.setActive(rule.id, false))
        backend.pendingContinuation?.resume()
        backend.pendingContinuation = nil
        await store.refreshReminders()
        XCTAssertTrue(backend.added.isEmpty)
        XCTAssertTrue(backend.requests.isEmpty)
    }
}

@MainActor
private final class ReminderClock {
    var now: Date
    init(_ now: Date) { self.now = now }
}

@MainActor
private final class FakeReminderClient {
    var status: UNAuthorizationStatus = .authorized
    var permissionRequests = 0
    var requests: [String: UNNotificationRequest] = [:]
    var added: [String] = []
    var removed: [String] = []
    var failAdds = false
    var blockNextPending = false
    var pendingContinuation: CheckedContinuation<Void, Never>?

    var client: ReminderClient {
        ReminderClient(authorization: { self.status }, requestAuthorization: {
            self.permissionRequests += 1
            self.status = .authorized
            return true
        }, pending: {
            if self.blockNextPending {
                self.blockNextPending = false
                await withCheckedContinuation { self.pendingContinuation = $0 }
            }
            return Array(self.requests.values)
        }, add: { request in
            if self.failAdds { throw CocoaError(.fileWriteUnknown) }
            self.requests[request.identifier] = request
            self.added.append(request.identifier)
        }, remove: { identifiers in
            self.removed += identifiers
            for id in identifiers { self.requests.removeValue(forKey: id) }
        })
    }
}
