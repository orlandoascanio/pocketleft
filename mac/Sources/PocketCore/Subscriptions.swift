import Foundation

/// A view over existing schedules: subscriptions never create a second payment.
public struct SubscriptionSummary {
    public let active: [Rule]
    public let paused: [Rule]
    public let otherRepeating: [Rule]
    public let renewals: [Occurrence]
    public let annual: Cents
    public var monthly: Cents { Int((Double(annual) / 12).rounded()) }
    public var upcomingTotal: Cents { renewals.reduce(0) { $0 - $1.cents } }
    public var overdue: [Rule] { active.filter { $0.next < today } }
    private let today: Day

    public init(ledger: Ledger, today: Day, days: Int = 30) {
        self.today = today
        let live = ledger.liveRules
        active = live.filter { $0.isSubscription && $0.active }
        paused = live.filter { $0.isSubscription && !$0.active }
        otherRepeating = live.filter { $0.cents < 0 && !$0.isOnce && !$0.isSubscription }
        let ids = Set(active.map(\.id))
        // Include every actual charge in the window, including weekly renewals, not just one per service.
        renewals = ledger.upcoming(today: today, days: days)
            .filter { ids.contains($0.ruleID) && $0.day >= today }
        annual = Int(active.reduce(0.0) { $0 + Double(-$1.cents) * $1.cadence.perMonth * 12 }.rounded())
    }
}
