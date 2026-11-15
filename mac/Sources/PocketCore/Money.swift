import Foundation

/// Formats and parses amounts in the person's chosen currency.
public struct Money: Sendable {
    public let currency: String
    public let locale: Locale

    public init(currency: String, locale: Locale = .current) {
        self.currency = currency
        self.locale = locale
    }

    // Formatters are mutable, so cache separate modes and keep every use under the cache lock.
    private static let formatters = CurrencyFormatters()

    /// Input precision follows the ledger's integer cents, regardless of display currency.
    public var fractionDigits: Int { 2 }

    /// "$", "€", "¥": shown beside an amount while it's typed.
    public var symbol: String {
        Self.formatters.use(currency: currency, locale: locale, mode: .standard) { $0.currencySymbol ?? currency }
    }

    /// What an empty amount field shows, matching the precision that can be recorded.
    public var placeholder: String { fractionDigits == 0 ? "0" : "0." + String(repeating: "0", count: fractionDigits) }

    public func string(_ cents: Cents, signed: Bool = false) -> String {
        let value = Double(cents) / 100
        // Keep a fractional recorded amount visible even for a whole-unit currency.
        let s = Self.formatters.use(currency: currency, locale: locale,
                                    mode: cents % 100 == 0 ? .standard : .fractional) {
            $0.string(from: NSNumber(value: value)) ?? "\(value)"
        }
        return signed && cents > 0 ? "+" + s : s
    }

    /// "$1.2K" style, for chart axes.
    public func compact(_ cents: Cents) -> String {
        let value = Double(cents) / 100
        let mag = abs(value)
        let (n, suffix) = mag >= 1_000_000 ? (value / 1_000_000, "M") : mag >= 1_000 ? (value / 1_000, "K") : (value, "")
        return Self.formatters.use(currency: currency, locale: locale, mode: suffix.isEmpty ? .whole : .compact) {
            ($0.string(from: NSNumber(value: n)) ?? "\(n)") + suffix
        }
    }

    /// Whole units only ("$750"), for rough monthly totals.
    public func whole(_ cents: Cents) -> String {
        Self.formatters.use(currency: currency, locale: locale, mode: .whole) {
            $0.string(from: NSNumber(value: (Double(cents) / 100).rounded())) ?? "\(cents / 100)"
        }
    }

    /// Reads what someone typed ("9.99", "9,99", "$9.99", "1,234.50") as a positive amount in cents.
    public static func parse(_ text: String, allowZero: Bool = false) -> Cents? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Accept a pasted currency symbol, but never silently discard arbitrary text or digits.
        if let first = s.unicodeScalars.first, first.properties.generalCategory == .currencySymbol {
            s.removeFirst()
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let last = s.unicodeScalars.last, last.properties.generalCategory == .currencySymbol {
            s.removeLast()
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if s.hasPrefix("+") || s.hasPrefix("-") { s.removeFirst() }
        guard s.contains(where: { "0123456789".contains($0) }),
              s.allSatisfy({ "0123456789.,".contains($0) }) else { return nil }
        let integer: String
        let fraction: String
        if s.contains("."), s.contains(",") {
            let decimal = s.lastIndex(where: { $0 == "." || $0 == "," })!
            let grouping: Character = s[decimal] == "." ? "," : "."
            let whole = String(s[..<decimal])
            guard validGroupedInteger(whole, separator: grouping) else { return nil }
            integer = whole.replacingOccurrences(of: String(grouping), with: "")
            fraction = String(s[s.index(after: decimal)...])
            guard (1...2).contains(fraction.count), fraction.allSatisfy({ "0123456789".contains($0) }) else { return nil }
        } else if let separator = s.first(where: { $0 == "." || $0 == "," }) {
            let parts = s.split(separator: separator, omittingEmptySubsequences: false)
            if parts.count == 2 && parts[1].count <= 2 {
                integer = parts[0].isEmpty ? "0" : String(parts[0])
                fraction = String(parts[1])
            } else {
                guard validGroupedInteger(s, separator: separator) else { return nil }
                integer = parts.joined()
                fraction = ""
            }
        } else {
            integer = s
            fraction = ""
        }
        guard let units = Int(integer), units < 1_000_000_000 else { return nil }
        let cents = units * 100 + (Int(fraction.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0)
        return cents > 0 || allowZero ? cents : nil
    }

    private static func validGroupedInteger(_ text: String, separator: Character) -> Bool {
        let parts = text.split(separator: separator, omittingEmptySubsequences: false)
        guard let first = parts.first else { return false }
        return (1...3).contains(first.count)
            && parts.allSatisfy { $0.allSatisfy { "0123456789".contains($0) } }
            && parts.dropFirst().allSatisfy { $0.count == 3 }
    }

    /// Cents as an editable string ("9.99").
    public static func edit(_ cents: Cents) -> String { String(format: "%.2f", Double(abs(cents)) / 100) }
}

/// A bounded cache shared by Money values. No formatter escapes the lock or changes mode after creation.
private final class CurrencyFormatters: @unchecked Sendable {
    enum Mode: String { case standard, fractional, compact, whole }
    private let lock = NSLock()
    private let cache = NSCache<NSString, NumberFormatter>()

    init() { cache.countLimit = 64 }

    func use<T>(currency: String, locale: Locale, mode: Mode, _ body: (NumberFormatter) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(locale.identifier)|\(currency)|\(mode.rawValue)" as NSString
        let formatter: NumberFormatter
        if let existing = cache.object(forKey: key) {
            formatter = existing
        } else {
            formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency
            formatter.locale = locale
            switch mode {
            case .standard: break
            case .fractional: formatter.maximumFractionDigits = max(2, formatter.maximumFractionDigits)
            case .compact:
                formatter.maximumFractionDigits = 1
                formatter.minimumFractionDigits = 0
            case .whole:
                formatter.maximumFractionDigits = 0
                formatter.minimumFractionDigits = 0
            }
            cache.setObject(formatter, forKey: key)
        }
        return body(formatter)
    }
}
