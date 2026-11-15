import PocketCore

/// Prepare sorting and running balances only when entries change, rather than on sync status updates.
struct HistorySnapshot {
    let entries: [Entry]
    let balanceAfter: [Entry.ID: Cents]
    private(set) var matching: [Entry]
    private(set) var netByDay: [Day: Cents] = [:]

    init(entries: [Entry] = [], query: EntryQuery = EntryQuery()) {
        self.entries = Ledger(entries: entries).sortedEntries
        var balances: [Entry.ID: Cents] = [:]
        var balance: Cents = 0
        for entry in self.entries.reversed() {
            balance += entry.cents
            balances[entry.id] = balance
        }
        balanceAfter = balances
        matching = []
        filter(query)
    }

    mutating func filter(_ query: EntryQuery) {
        matching = query.isEmpty ? entries : entries.filter(query.matches)
        netByDay = matching.reduce(into: [:]) { $0[$1.day, default: 0] += $1.cents }
    }
}
