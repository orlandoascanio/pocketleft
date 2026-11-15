import XCTest
@testable import Pocket

final class SyncScheduleTests: XCTestCase {
    func testVisibilityAndLowPowerModeReducePolling() {
        XCTAssertEqual(AccountConfig.syncInterval(active: true, lowPower: false, failures: 0), 30)
        XCTAssertEqual(AccountConfig.syncInterval(active: false, lowPower: false, failures: 0), 300)
        XCTAssertEqual(AccountConfig.syncInterval(active: true, lowPower: true, failures: 0), 900)
        XCTAssertEqual(AccountConfig.syncInterval(active: false, lowPower: true, failures: 0), 900)
    }

    func testRepeatedFailuresBackOffAndStayBounded() {
        XCTAssertEqual(AccountConfig.syncInterval(active: true, lowPower: false, failures: 1), 60)
        XCTAssertEqual(AccountConfig.syncInterval(active: false, lowPower: false, failures: 2), 1_200)
        XCTAssertEqual(AccountConfig.syncInterval(active: true, lowPower: true, failures: 1), 1_800)
        XCTAssertEqual(AccountConfig.syncInterval(active: true, lowPower: false, failures: 100), 1_800)
    }
}
