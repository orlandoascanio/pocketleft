import Foundation

public struct Category: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// SF Symbol name.
    public let symbol: String
}

public enum Categories {
    public static let start = "start"
    public static let uncategorized = "uncategorized"

    public static let spending: [Category] = [
        .init(id: "games", name: "Games", symbol: "gamecontroller"),
        .init(id: "subscriptions", name: "Subscriptions", symbol: "repeat"),
        .init(id: "bills", name: "Bills", symbol: "bolt"),
        .init(id: "apps", name: "Apps", symbol: "square.grid.2x2"),
        .init(id: "food", name: "Food", symbol: "cup.and.saucer"),
        .init(id: "shopping", name: "Shopping", symbol: "bag"),
        .init(id: "fun", name: "Fun", symbol: "sparkles"),
        .init(id: "transport", name: "Transport", symbol: "bus"),
        .init(id: "other", name: "Other", symbol: "ellipsis.circle"),
    ]

    public static let income: [Category] = [
        .init(id: "pay", name: "Pay", symbol: "banknote"),
        .init(id: "gift", name: "Gift", symbol: "gift"),
        .init(id: "refund", name: "Refund", symbol: "arrow.uturn.backward"),
        .init(id: "otherin", name: "Other", symbol: "arrow.down.left"),
    ]

    public static let all = spending + income + [.init(id: start, name: "Starting balance", symbol: "banknote")]

    public static func find(_ id: String?) -> Category? { all.first { $0.id == id } }
    /// Group entries with no assigned category without changing the stored entry.
    public static func key(_ id: String?) -> String { id ?? uncategorized }
    public static func name(_ id: String?) -> String { find(id)?.name ?? "Uncategorized" }
    public static func symbol(_ id: String?, cents: Cents) -> String {
        find(id)?.symbol ?? (cents > 0 ? "arrow.down.left" : "arrow.up.right")
    }
}

/// What the pocket says. Pools by context, dealt like a shuffled deck so lines don't repeat until it runs out.
public final class Lines: @unchecked Sendable {
    public static let shared = Lines()

    public static let pools: [String: [String]] = [
        "in": ["Yum!", "Ooh, shiny!", "Thank you!", "Mmm, coins", "More, please", "Cha-ching!", "Feeling richer", "Into the pocket!", "Coin acquired", "Jingle jingle"],
        "inBig": ["Payday!", "Big money!", "Whoa, nice!", "We're rich! (ish)", "Look at all these coins", "So heavy now"],
        "gift": ["A gift? How lovely", "Someone likes you", "Free money!", "Say thank you!"],
        "refund": ["Money back!", "Refund secured", "It came back home"],
        "out": ["Oof", "Bye-bye, coin", "There it goes", "Spent!", "Hope it was worth it", "See you, coin", "Lighter pocket", "And it's gone"],
        "outBig": ["Whoa, big one", "That was a lot of coins", "Ouch", "My pocket felt that"],
        "outSmall": ["Just a tiny one", "Pocket change", "Barely felt it"],
        "games": ["Another game? Have fun", "Game on!", "GG", "Add it to the backlog", "Player one ready", "Just one more game…"],
        "subscriptions": ["Another subscription…", "Monthly friend added", "Subscribed!", "Renewing, renewing"],
        "bills": ["Adulting", "Bills, bills, bills", "Responsible!", "Lights stay on"],
        "apps": ["New app, new me", "Installed!", "Shiny new app"],
        "food": ["Bon appétit", "Snack time", "Was it tasty?"],
        "shopping": ["Ooh, what did you get?", "Retail therapy", "Show me later"],
        "fun": ["Have fun!", "Treat yourself", "Enjoy it!"],
        "transport": ["Safe travels", "Vroom", "Off you go"],
        "waiting": ["Can't wait!", "Counting the days", "Soon…", "I'll keep an eye out"],
        "planned": ["I'll remember it", "Noted", "On the calendar"],
        "poke": ["Hehe", "That tickles!", "Still here!", "Hi there", "Boop", "Careful, I'm full of coins", "Need something?", "*jingle*", "Again!", "You found me"],
        "morning": ["Morning!", "Good morning", "Rise and shine"],
        "night": ["Up late?", "Night owl!", "Sleep soon"],
        "skip": ["Skipped!", "Maybe next time", "Okay, not this one"],
        "paused": ["Taking a nap", "Paused!"],
        "resumed": ["Back at it!", "Awake again"],
        "deleted": ["Poof!", "Gone", "Never happened"],
        "welcome": ["Hi! I'm your Pocket", "Nice to meet you!", "Let's keep an eye on your coins"],
    ]

    private var decks: [String: [String]] = [:]
    private let lock = NSLock()

    public func line(_ pool: String) -> String {
        lock.lock(); defer { lock.unlock() }
        if decks[pool]?.isEmpty ?? true { decks[pool] = (Lines.pools[pool] ?? ["Hi"]).shuffled() }
        return decks[pool]!.removeLast()
    }

    /// The right line for a change in the balance.
    public func forChange(_ diff: Cents, category: String?) -> String {
        if diff > 0 {
            if category == "gift" || category == "refund" { return line(category!) }
            return line(diff >= 20_000 ? "inBig" : "in")
        }
        if let c = category, Lines.pools[c] != nil, Double.random(in: 0...1) < 0.6 { return line(c) }
        return line(-diff >= 5_000 ? "outBig" : -diff < 200 ? "outSmall" : "out")
    }
}
