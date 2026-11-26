import Foundation
import SentrySwift
import XCTest
@testable import Pocket

@MainActor
final class CrashReportingTests: XCTestCase {
    func testNeverRunsInDebugBuildsOrTests() {
        XCTAssertFalse(CrashReporting.available)
        CrashReporting.update(enabled: true)
        XCTAssertFalse(CrashReporting.running)
    }

    /// Sends one real event with the shipping configuration. Run on purpose only:
    /// POCKET_SENTRY_LIVE_TEST=1 swift test --filter CrashReportingTests
    func testLiveEventReachesSentry() throws {
        guard ProcessInfo.processInfo.environment["POCKET_SENTRY_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set POCKET_SENTRY_LIVE_TEST=1 to send a real test event to Sentry.")
        }
        CrashReporting.start(environment: "setup-check")
        let id = SentrySDK.capture(message: "Pocket for Mac Sentry setup check")
        SentrySDK.flush(timeout: 10)
        CrashReporting.stop()
        print("POCKET_SENTRY_EVENT_ID=\(id.sentryIdString)")
    }
}
