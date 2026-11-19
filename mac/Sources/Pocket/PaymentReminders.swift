import Foundation
import PocketCore
@preconcurrency import UserNotifications

struct RenewalReminderTiming: Codable, Hashable {
    enum Unit: String, Codable {
        case hours, days

        var range: ClosedRange<Int> {
            switch self {
            case .hours: 1...8_760
            case .days: 1...365
            }
        }
    }

    var amount = 2
    var unit = Unit.days
    var minuteOfDay = 10 * 60

    var isValid: Bool { unit.range.contains(amount) && (0..<1_440).contains(minuteOfDay) }

    func date(before renewal: Day, calendar: Calendar) -> Date? {
        switch unit {
        case .hours:
            let components = DateComponents(year: renewal.year, month: renewal.month, day: renewal.day)
            return calendar.date(from: components).map { calendar.startOfDay(for: $0).addingTimeInterval(-Double(amount) * 3_600) }
        case .days:
            let day = renewal.adding(days: -amount)
            return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day,
                                                       hour: minuteOfDay / 60, minute: minuteOfDay % 60))
        }
    }
}

enum RenewalReminder: Codable, Hashable {
    case relative(RenewalReminderTiming)
    case exact(day: Day, minuteOfDay: Int, renewal: Day)

    func date(for renewal: Day, calendar: Calendar = .current) -> Date? {
        switch self {
        case .relative(let timing):
            return timing.isValid ? timing.date(before: renewal, calendar: calendar) : nil
        case let .exact(day, minuteOfDay, target):
            guard target == renewal, day < renewal, (0..<1_440).contains(minuteOfDay) else { return nil }
            return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day,
                                                       hour: minuteOfDay / 60, minute: minuteOfDay % 60))
        }
    }
}

struct RenewalReminderPreferences: Codable, Equatable {
    var defaults: [RenewalReminder] = [.relative(.init())]
    var subscriptions: [UUID: [RenewalReminder]] = [:]

    func reminders(for id: UUID) -> [RenewalReminder] { subscriptions[id] ?? defaults }
}

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
                      payments: Bool = true, subscriptions: Bool = false,
                      renewalPreferences: RenewalReminderPreferences = .init()) -> [PaymentReminder] {
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
        let renewalPlans = rules.filter { subscriptions && $0.isSubscription && $0.active && !$0.finished }.flatMap { rule in
            renewalPreferences.reminders(for: rule.id).flatMap { reminder -> [PaymentReminder] in
                switch reminder {
                case .relative:
                    return plans(forRenewalOf: rule, reminder: reminder, now: now, today: today, calendar: calendar)
                case .exact:
                    guard let date = reminder.date(for: rule.next, calendar: calendar),
                          Day(date, calendar: calendar) >= today else { return [] }
                    return [renewalPlan(for: rule, index: rule.posted, renewal: rule.next, date: date, calendar: calendar)]
                }
            }
        }
        var seen = Set<String>()
        return (paymentPlans + renewalPlans).filter { seen.insert($0.identifier).inserted }.sorted { $0.date < $1.date }
    }

    private static func plans(forRenewalOf rule: Rule, reminder: RenewalReminder, now: Date,
                              today: Day, calendar: Calendar) -> [PaymentReminder] {
        var plans: [PaymentReminder] = []
        var previousRenewal: Day?
        for offset in 0..<400 {
            let index = rule.posted + offset
            if let total = rule.total, index >= total { break }
            let renewal = rule.occurrence(index)
            guard let date = reminder.date(for: renewal, calendar: calendar) else { break }
            let day = Day(date, calendar: calendar)
            // Check later charges when a long lead time overlaps this cycle or a charge is already due.
            if let previousRenewal, previousRenewal > today, day >= previousRenewal { break }
            previousRenewal = renewal
            guard day >= today else { continue }
            plans.append(renewalPlan(for: rule, index: index, renewal: renewal, date: date, calendar: calendar))
            // Keep a request due earlier today while macOS delivers it, and queue the first future one.
            if date > now { break }
        }
        return plans
    }

    private static func renewalPlan(for rule: Rule, index: Int, renewal: Day, date: Date, calendar: Calendar) -> PaymentReminder {
        let day = Day(date, calendar: calendar)
        let renewalDate = calendar.date(from: DateComponents(year: renewal.year, month: renewal.month, day: renewal.day, hour: 12))
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone)
        let when = day.adding(days: 1) == renewal ? "tomorrow" : "on \(renewalDate?.formatted(style) ?? renewal.iso)"
        // Include the fire time so changing timing can cancel even a same-day request.
        let timestamp = Int(date.timeIntervalSince1970)
        return PaymentReminder(identifier: "pocket.subscription.\(rule.id.uuidString).\(index).\(timestamp).\(day.iso)",
                               day: day, date: date, title: "\(rule.label) renews \(when)",
                               body: "Open Subscriptions in Pocket to review the charge.", catchUp: false)
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
