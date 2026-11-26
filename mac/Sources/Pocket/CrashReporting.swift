import Foundation
import SentrySwift

/// Crash and error reports sent to Sentry (project pocket-mac).
///
/// Follows the "Share anonymous usage data and crash reports" switch: on by default, and turning
/// it off stops reporting. Only release builds of the installed app report; debug builds, tests
/// and demo data folders never do. Reports carry the crash and device basics, never money data:
/// no breadcrumbs, network details, user or computer name.
@MainActor
enum CrashReporting {
    static let dsn = "https://5664005ba0e2b06765e8d2f0ffe92999@o4510075179827200.ingest.us.sentry.io/4512500546797568"
    private(set) static var running = false

    static var available: Bool {
        #if DEBUG
        return false
        #else
        return ProcessInfo.processInfo.environment["POCKET_DATA_DIR"] == nil
        #endif
    }

    static func update(enabled: Bool) {
        guard available else { return }
        if enabled && !running {
            start()
        } else if !enabled && running {
            stop()
        }
    }

    static func stop() {
        SentrySDK.close()
        running = false
    }

    /// Internal so a live test can check the real configuration reaches Sentry.
    static func start(environment: String = "production") {
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environment
            options.sendDefaultPii = false
            options.maxBreadcrumbs = 0
            options.enableAutoBreadcrumbTracking = false
            options.enableNetworkBreadcrumbs = false
            options.enableNetworkTracking = false
            options.enableCaptureFailedRequests = false
            options.enableAutoPerformanceTracing = false
            options.tracesSampleRate = 0
            // AppKit swallows exceptions on the main thread unless this is on.
            options.enableUncaughtNSExceptionReporting = true
            options.beforeSend = { event in
                event.user = nil
                event.serverName = nil // The Mac's name, often the owner's name.
                return event
            }
        }
        running = true
    }
}
