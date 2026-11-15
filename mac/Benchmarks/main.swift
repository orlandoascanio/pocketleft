import Foundation
public typealias Cents = Int
let money = Money(currency: "USD", locale: Locale(identifier: "en_US"))
let reused = NumberFormatter()
reused.numberStyle = .currency
reused.currencyCode = "USD"
reused.locale = Locale(identifier: "en_US")
func measure(_ name: String, count: Int, format: (Int) -> String) -> Int {
    var times: [Double] = []
    var checksum = 0
    for _ in 0..<3 {
        let start = ContinuousClock.now
        for i in 1...count { checksum &+= format(i).utf8.count }
        let d = start.duration(to: .now).components
        times.append(Double(d.seconds) * 1000 + Double(d.attoseconds) / 1e15)
    }
    print("\(name), count=\(count), median_ms=\(String(format: "%.2f", times.sorted()[1])), checksum=\(checksum)")
    return checksum
}
for n in [1000, 10000] {
    let a = measure("Pocket Money.string", count: n) { money.string($0) }
    let b = measure("Reused formatter reference", count: n) { reused.string(from: NSNumber(value: Double($0) / 100))! }
    precondition(a == b)
}
