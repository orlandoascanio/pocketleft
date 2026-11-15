import Foundation
import PocketCore
import XCTest

final class MoneyFormattingTests: XCTestCase {
    func testFormattingModesDoNotChangeLaterAmounts() {
        let usd = Money(currency: "USD", locale: Locale(identifier: "en_US"))
        let yen = Money(currency: "JPY", locale: Locale(identifier: "en_US"))
        for _ in 0..<3 {
            XCTAssertEqual(usd.compact(123_450), "$1.2K")
            XCTAssertEqual(usd.compact(12_345), "$123")
            XCTAssertEqual(usd.whole(12_350), "$124")
            XCTAssertEqual(usd.string(12_345), "$123.45")
            XCTAssertEqual(usd.string(12_300, signed: true), "+$123.00")
            XCTAssertEqual(yen.string(12_345), "¥123.45")
            XCTAssertEqual(yen.string(12_300), "¥123")
            XCTAssertEqual(usd.symbol, "$")
            XCTAssertEqual(yen.symbol, "¥")
        }
    }

    func testConcurrentCurrenciesAndLocalesMatchFreshFormatters() {
        // Build independent Foundation results before concurrent use of the shared cache.
        let cases = ["en_US", "de_DE", "fr_FR"].flatMap { locale in
            ["USD", "EUR", "JPY"].map { currency -> (Money, String, String) in
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.currencyCode = currency
                formatter.locale = Locale(identifier: locale)
                formatter.maximumFractionDigits = max(2, formatter.maximumFractionDigits)
                return (Money(currency: currency, locale: Locale(identifier: locale)),
                        formatter.string(from: NSNumber(value: -123.45))!, formatter.currencySymbol)
            }
        }
        DispatchQueue.concurrentPerform(iterations: 300) { index in
            let (money, expected, symbol) = cases[index % cases.count]
            _ = money.whole(98_765)
            _ = money.compact(9_876_543)
            XCTAssertEqual(money.string(-12_345), expected)
            XCTAssertEqual(money.symbol, symbol)
        }
    }
}
