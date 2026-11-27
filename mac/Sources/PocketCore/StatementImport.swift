import Foundation

// Reading a bank or card statement exported as CSV, so a missed week can be caught up in one go.
// Pure and testable: it only reads text and compares against the ledger. Adding the rows (and undoing
// the whole import) is the app's job.

/// Splits CSV text into rows of fields. Handles quotes, escaped quotes, CRLF, a byte order mark,
/// and semicolon- or tab-separated exports.
public enum CSVReader {
    public static func rows(_ text: String) -> [[String]] {
        var s = text
        if s.hasPrefix("\u{FEFF}") { s.removeFirst() }
        let delimiter = guessDelimiter(s)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var chars = Array(s)
        chars.append("\n")
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 } else { quoted = false }
                } else {
                    field.append(c)
                }
            } else if c == "\"" && field.trimmingCharacters(in: .whitespaces).isEmpty {
                field = ""
                quoted = true
            } else if c == delimiter {
                row.append(field)
                field = ""
            } else if c == "\n" || c == "\r" || c == "\r\n" {
                if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                row.append(field)
                field = ""
                if !row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { rows.append(row) }
                row = []
            } else {
                field.append(c)
            }
            i += 1
        }
        return rows.map { $0.map { $0.trimmingCharacters(in: .whitespaces) } }
    }

    /// The separator that splits the first lines most consistently into more than one field.
    static func guessDelimiter(_ text: String) -> Character {
        let lines = text.split(whereSeparator: \.isNewline).prefix(20)
        var best: (Character, Int) = (",", 0)
        for candidate in [",", ";", "\t"] as [Character] {
            let counts = lines.map { line in line.filter { $0 == candidate }.count }
            guard let top = counts.max(), top > 0 else { continue }
            let consistent = counts.filter { $0 == top }.count
            if consistent > best.1 || (consistent == best.1 && candidate == ",") { best = (candidate, consistent) }
        }
        return best.0
    }
}

/// Which column holds what. `amount` is a signed amount; `debit` and `credit` are money out and in.
public struct StatementColumns: Equatable, Sendable {
    public var headerRow: Int?
    public var date: Int
    public var description: Int?
    public var amount: Int?
    public var debit: Int?
    public var credit: Int?
}

public struct StatementRow: Identifiable, Equatable, Sendable {
    public enum Duplicate: Equatable, Sendable {
        /// Already in Pocket: same amount within a few days.
        case recorded(Entry)
        /// The same date, amount and description appear earlier in this file.
        case repeated(line: Int)
    }

    /// The line number in the file, starting at 1.
    public var line: Int
    public var day: Day
    public var label: String
    /// Negative is money out.
    public var cents: Cents
    public var category: String?
    public var duplicate: Duplicate?
    public var id: Int { line }

    /// Imported unless someone changes it: likely duplicates of recorded entries start unchecked.
    public var includedByDefault: Bool {
        if case .recorded = duplicate { return false }
        return true
    }
}

public struct SkippedLine: Equatable, Sendable {
    public var line: Int
    public var reason: String
}

public struct StatementPreview: Sendable {
    public var columns: StatementColumns
    public var rows: [StatementRow]
    public var skipped: [SkippedLine]
    /// Every date would read the same as month/day or day/month, so the person should say which.
    public var ambiguousDates: Bool
    /// Whether dates were read day first.
    public var dayFirst: Bool
    public var duplicates: Int { rows.filter { $0.duplicate != nil }.count }
    public var firstDay: Day? { rows.map(\.day).min() }
    public var lastDay: Day? { rows.map(\.day).max() }
}

public enum StatementImport {
    public static let maxRows = 5_000
    /// Entries this many days apart can be the same purchase: a card often posts a day or two later.
    public static let duplicateWindow = 3
    static let maxLabel = 120

    /// Reads a statement and compares it with what's already recorded.
    /// `dayFirst` nil picks from the dates themselves, then `localeDayFirst` when they could go either way.
    /// `flipSigns` is for card statements that list purchases as positive amounts.
    public static func preview(_ text: String, ledger: Ledger, today: Day, dayFirst: Bool? = nil,
                               localeDayFirst: Bool = false, flipSigns: Bool = false) throws -> StatementPreview {
        let table = CSVReader.rows(text)
        guard !table.isEmpty else { throw LedgerError("This file is empty.") }
        guard let columns = detectColumns(table) else {
            throw LedgerError("Pocket couldn't find a date column and an amount column in this file.")
        }
        let body = Array(table.enumerated().dropFirst((columns.headerRow ?? -1) + 1))
        guard body.count <= maxRows else { throw LedgerError("This file has more than \(maxRows) rows. Export a shorter date range.") }

        let order = dateOrder(body.map { field($0.element, columns.date) })
        let useDayFirst = dayFirst ?? order.dayFirst ?? localeDayFirst
        var rows: [StatementRow] = []
        var skipped: [SkippedLine] = []
        for (index, cells) in body {
            let line = index + 1
            let dateText = field(cells, columns.date)
            guard let day = parseDate(dateText, dayFirst: useDayFirst) else {
                skipped.append(SkippedLine(line: line, reason: dateText.isEmpty ? "No date" : "Unreadable date “\(dateText)”"))
                continue
            }
            var cents: Cents?
            if let a = columns.amount { cents = parseAmount(field(cells, a)) }
            if cents == nil || cents == 0, columns.debit != nil || columns.credit != nil {
                let out = columns.debit.flatMap { parseAmount(field(cells, $0)) }.map(abs) ?? 0
                let into = columns.credit.flatMap { parseAmount(field(cells, $0)) }.map(abs) ?? 0
                cents = into - out
            }
            guard var amount = cents, amount != 0 else {
                skipped.append(SkippedLine(line: line, reason: "No amount"))
                continue
            }
            if flipSigns { amount = -amount }
            guard abs(amount) <= 99_999_999_999 else {
                skipped.append(SkippedLine(line: line, reason: "Amount too large"))
                continue
            }
            if day > today.adding(days: 1) {
                skipped.append(SkippedLine(line: line, reason: "Dated in the future"))
                continue
            }
            var label = columns.description.map { field(cells, $0) } ?? ""
            label = label.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            if label.isEmpty { label = amount < 0 ? "Card purchase" : "Deposit" }
            if label.count > maxLabel { label = String(label.prefix(maxLabel)) }
            rows.append(StatementRow(line: line, day: day, label: label, cents: amount,
                                     category: guessCategory(label, income: amount > 0, ledger: ledger)))
        }
        markDuplicates(&rows, ledger: ledger)
        return StatementPreview(columns: columns, rows: rows, skipped: skipped,
                                ambiguousDates: dayFirst == nil && order.dayFirst == nil && order.numeric, dayFirst: useDayFirst)
    }

    static func field(_ cells: [String], _ i: Int) -> String { i < cells.count ? cells[i] : "" }

    // MARK: columns

    private static func normalized(_ header: String) -> String {
        header.lowercased().folding(options: .diacriticInsensitive, locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func find(_ headers: [String], _ names: [String], excluding: [String] = [], taken: Set<Int> = []) -> Int? {
        for name in names {
            if let i = headers.indices.first(where: { i in
                !taken.contains(i) && (headers[i] == name || headers[i].hasPrefix(name + " ") || headers[i].hasSuffix(" " + name)
                                       || headers[i].contains(" " + name + " "))
                    && !excluding.contains(where: { headers[i].contains($0) })
            }) { return i }
        }
        return nil
    }

    static func detectColumns(_ table: [[String]]) -> StatementColumns? {
        for (r, row) in table.prefix(15).enumerated() {
            let h = row.map(normalized)
            guard let date = find(h, ["transaction date", "trans date", "date", "posted date", "posting date", "booking date",
                                      "value date", "fecha", "datum", "posted"]) else { continue }
            let balance = ["balance", "saldo"]
            let amount = find(h, ["amount", "transaction amount", "importe", "monto", "betrag", "value"], excluding: balance + ["date"],
                              taken: [date])
            let debit = find(h, ["debit", "debit amount", "withdrawal", "withdrawals", "money out", "paid out", "outflow", "cargo"],
                             excluding: balance + ["date"], taken: [date])
            let credit = find(h, ["credit", "credit amount", "deposit", "deposits", "money in", "paid in", "inflow", "abono"],
                              excluding: balance + ["date", "card"], taken: [date])
            guard amount != nil || debit != nil || credit != nil else { continue }
            let used = Set([date, amount, debit, credit].compactMap { $0 })
            let description = find(h, ["description", "payee", "merchant", "name", "details", "narrative", "memo",
                                       "transaction description", "concepto", "descripcion", "beschreibung", "reference", "transaction"],
                                   excluding: ["date", "type"], taken: used)
            return StatementColumns(headerRow: r, date: date, description: description, amount: amount, debit: debit, credit: credit)
        }
        // No header: the first row with a date and an amount shows the layout.
        for row in table.prefix(5) {
            guard let date = row.indices.first(where: { parseDate(row[$0], dayFirst: false) != nil || parseDate(row[$0], dayFirst: true) != nil })
            else { continue }
            guard let amount = row.indices.last(where: { $0 != date && parseAmount(row[$0]) != nil }) else { continue }
            let description = row.indices.filter { $0 != date && $0 != amount && parseAmount(row[$0]) == nil }
                .max { row[$0].count < row[$1].count }
            return StatementColumns(headerRow: nil, date: date, description: description, amount: amount)
        }
        return nil
    }

    // MARK: dates

    private static let monthNames: [String: Int] = {
        var out: [String: Int] = [:]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for (i, name) in f.monthSymbols.enumerated() {
            out[name.lowercased()] = i + 1
            out[String(name.lowercased().prefix(3))] = i + 1
        }
        out["sept"] = 9
        return out
    }()

    /// Whether numeric dates in the file can only be day-first (a first part over 12) or only month-first.
    static func dateOrder(_ texts: [String]) -> (dayFirst: Bool?, numeric: Bool) {
        var firstOver12 = false, secondOver12 = false, numeric = false
        for t in texts {
            guard let parts = numericParts(t), parts.count == 3, parts[0].count <= 2 else { continue }
            numeric = true
            if let a = Int(parts[0]), a > 12 { firstOver12 = true }
            if let b = Int(parts[1]), b > 12 { secondOver12 = true }
        }
        if firstOver12 && !secondOver12 { return (true, numeric) }
        if secondOver12 && !firstOver12 { return (false, numeric) }
        return (nil, numeric)
    }

    private static func numericParts(_ text: String) -> [String]? {
        let token = text.split(whereSeparator: { $0 == " " || $0 == "T" }).first.map(String.init) ?? ""
        let parts = token.split(whereSeparator: { $0 == "/" || $0 == "." || $0 == "-" }).map(String.init)
        guard (2...3).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }
        return parts
    }

    /// "2026-11-20", "11/20/2026", "20/11/26", "20.11.2026", "Nov 20, 2026", "20 Nov 2026", "20-Nov-26",
    /// with or without a time after it.
    public static func parseDate(_ text: String, dayFirst: Bool) -> Day? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        if let parts = numericParts(t), parts.count == 3 {
            func make(_ y: String, _ m: String, _ d: String) -> Day? {
                guard var year = Int(y), let month = Int(m), let day = Int(d) else { return nil }
                if y.count == 2 { year += 2000 }
                return Day(iso: String(format: "%04d-%02d-%02d", year, month, day))
            }
            if parts[0].count == 4 { return make(parts[0], parts[1], parts[2]) }
            guard parts[2].count == 4 || parts[2].count == 2 else { return nil }
            return dayFirst ? make(parts[2], parts[1], parts[0]) : make(parts[2], parts[0], parts[1])
        }
        // Month names: "Nov 20, 2026", "20 Nov 2026", "20-Nov-26".
        let words = t.lowercased().components(separatedBy: CharacterSet(charactersIn: " ,-/.")).filter { !$0.isEmpty }
        guard words.count >= 3 else { return nil }
        var month: Int?, day: Int?, year: Int?
        for w in words.prefix(3) {
            if let m = monthNames[w] { month = m; continue }
            guard let n = Int(w) else { return nil }
            if w.count == 4 { year = n } else if day == nil { day = n } else { year = 2000 + n }
        }
        guard let month, let day, let year else { return nil }
        return Day(iso: String(format: "%04d-%02d-%02d", year, month, day))
    }

    // MARK: amounts

    /// "-12.34", "(12.34)", "12.34-", "$1,234.56", "1.234,56 €", "12.34 DR", "USD 12.34". Signed cents.
    public static func parseAmount(_ text: String) -> Cents? {
        var s = text.trimmingCharacters(in: .whitespaces).uppercased()
        guard !s.isEmpty else { return nil }
        var negative = false
        if s.hasPrefix("(") && s.hasSuffix(")") { negative = true; s = String(s.dropFirst().dropLast()) }
        for suffix in [" DR", "DR"] where s.hasSuffix(suffix) { negative = true; s.removeLast(suffix.count); break }
        for suffix in [" CR", "CR"] where s.hasSuffix(suffix) { s.removeLast(suffix.count); break }
        s = s.filter { !$0.isLetter && !$0.isWhitespace && !($0.unicodeScalars.first?.properties.generalCategory == .currencySymbol) }
        if s.hasPrefix("-") || s.hasPrefix("−") { negative.toggle(); s.removeFirst() } else if s.hasPrefix("+") { s.removeFirst() }
        if s.hasSuffix("-") { negative.toggle(); s.removeLast() }
        guard let cents = Money.parse(s, allowZero: true) else { return nil }
        return negative ? -cents : cents
    }

    /// A category from a recorded entry or button with a similar name ("Coffee" for "COFFEE SHOP #12").
    static func guessCategory(_ label: String, income: Bool, ledger: Ledger) -> String? {
        if let c = ledger.guessCategory(for: label, income: income) { return c }
        let k = key(label)
        guard k.count >= 3 else { return nil }
        let allowed = Set((income ? Categories.income : Categories.spending).map(\.id))
        func similar(_ other: String) -> Bool {
            let o = key(other)
            return o.count >= 3 && (k.hasPrefix(o) || o.hasPrefix(k))
        }
        if let p = ledger.presets.first(where: { ($0.category.map(allowed.contains) ?? false) && similar($0.label) }) { return p.category }
        return ledger.sortedEntries.first { ($0.category.map(allowed.contains) ?? false) && similar($0.label) }?.category
    }

    // MARK: duplicates

    private static func key(_ label: String) -> String {
        label.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Each recorded entry can explain at most one row: the closest day with the same amount.
    static func markDuplicates(_ rows: inout [StatementRow], ledger: Ledger) {
        var pool = ledger.entries.filter { $0.category != Categories.start }
        var seen: [String: Int] = [:]
        let byDay = rows.indices.sorted { (rows[$0].day, rows[$0].line) < (rows[$1].day, rows[$1].line) }
        for i in byDay {
            let row = rows[i]
            let candidates = pool.indices.filter {
                pool[$0].cents == row.cents && abs(pool[$0].day.days(until: row.day)) <= duplicateWindow
            }
            if let best = candidates.min(by: { a, b in
                let da = abs(pool[a].day.days(until: row.day)), db = abs(pool[b].day.days(until: row.day))
                if da != db { return da < db }
                return (key(pool[a].label) == key(row.label) ? 0 : 1) < (key(pool[b].label) == key(row.label) ? 0 : 1)
            }) {
                rows[i].duplicate = .recorded(pool[best])
                pool.remove(at: best)
                continue
            }
            let k = "\(row.day.iso)|\(row.cents)|\(key(row.label))"
            if let first = seen[k] { rows[i].duplicate = .repeated(line: first) } else { seen[k] = row.line }
        }
    }
}
