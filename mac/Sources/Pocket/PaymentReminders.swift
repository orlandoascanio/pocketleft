import Foundation
import PocketCore
@preconcurrency import UserNotifications

struct PaymentReminder {
    let identifier: String
    let day: Day
    let date: Date
    let title: String
    var body = "Open Pocket to log it, with the real amount if it changed."
    var catchUp = true

    var content: UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = ["subscriptions": identifier.hasPrefix("pocket.subscription.")]
        content.sound = .default
        return content
    }
}

enum PaymentReminders {
    static let testIdentifier = "pocket-test-reminder"

    static func plans(for rules: [Rule], now: Date, calendar: Calendar = .current,
                      payments: Bool = true, subscriptions: Bool = false) -> [PaymentReminder] {
        let today = Day(now, calendar: calendar)
        let paymentPlans = rules.filter { payments && $0.active && !$0.auto && !$0.finished && $0.next >= today }.compactMap { rule -> PaymentReminder? in
            let day = rule.next
            var components = DateComponents(year: day.year, month: day.month, day: day.day, hour: 10)
            components.timeZone = calendar.timeZone
            guard let date = calendar.date(from: components) else { return nil }
            // Added after its reminder time had already passed (like money marked as still waiting today): no catch-up.
            if date <= now && rule.created > date && rule.posted == 0 { return nil }
            return PaymentReminder(identifier: "pocket.\(rule.id.uuidString).\(rule.posted).\(day.iso)",
                                   day: day, date: date,
                                   title: rule.cents > 0 ? "Did \(rule.label) pay?" : "Was \(rule.label) paid?")
        }
        let renewalPlans = rules.filter { subscriptions && $0.isSubscription && $0.active && !$0.finished }.compactMap { rule -> PaymentReminder? in
            let day = rule.next.adding(days: -1)
            var components = DateComponents(year: day.year, month: day.month, day: day.day, hour: 10)
            components.timeZone = calendar.timeZone
            // A renewal warning is useful before the charge, never as a late catch-up.
            guard day >= today, let date = calendar.date(from: components) else { return nil }
            return PaymentReminder(identifier: "pocket.subscription.\(rule.id.uuidString).\(rule.posted).\(day.iso)",
                                   day: day, date: date, title: "\(rule.label) renews tomorrow",
                                   body: "Open Subscriptions in Pocket to review the next charge.", catchUp: false)
        }
        return (paymentPlans + renewalPlans).sorted { $0.date < $1.date }
    }

    static func calendarTrigger(for reminder: PaymentReminder, calendar: Calendar = .current) -> UNCalendarNotificationTrigger {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.date)
        components.timeZone = calendar.timeZone
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}

/// The scheduler uses the same interface for macOS delivery and deterministic regression tests.
@MainActor
struct ReminderClient {
    var authorization: () async -> UNAuthorizationStatus
    var requestAuthorization: () async throws -> Bool
    var pending: () async -> [UNNotificationRequest]
    var add: (UNNotificationRequest) async throws -> Void
    var remove: ([String]) -> Void

    static var system: Self {
        let center = UNUserNotificationCenter.current()
        return Self(
            authorization: {
                await withCheckedContinuation { continuation in
                    center.getNotificationSettings { continuation.resume(returning: $0.authorizationStatus) }
                }
            },
            requestAuthorization: {
                try await withCheckedThrowingContinuation { continuation in
                    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume(returning: granted) }
                    }
                }
            },
            pending: {
                await withCheckedContinuation { continuation in
                    center.getPendingNotificationRequests { continuation.resume(returning: $0) }
                }
            },
            add: { request in
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    center.add(request) { error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume() }
                    }
                }
            },
            remove: { center.removePendingNotificationRequests(withIdentifiers: $0) }
        )
    }
}
