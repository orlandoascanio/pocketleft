import Foundation

/// Anonymous usage counts sent to PostHog. On by default; turning off
/// "Share anonymous usage data" in Settings stops them.
///
/// Events are a fixed list with no free-form properties, so amounts, labels, categories,
/// currencies, balances and sync details can't be sent. The ID is random and is deleted
/// when sharing is turned off; turning it back on starts a new one.
@MainActor
final class UsageAnalytics {
    enum Event: String, CaseIterable {
        /// Sent when a new random ID is made: a new install, an update to this version, or sharing turned back on.
        case firstSeen = "app_first_seen"
        /// At most once per calendar day while the app runs.
        case appActive = "app_active"
        /// The app runs a newer version than the last one it saw.
        case appUpdated = "app_updated"
        case entryAdded = "entry_added"
        case paymentScheduled = "payment_scheduled"
        case syncConnected = "sync_connected"
    }

    /// Sends one prepared request. Production uses URLSession; tests capture requests instead.
    typealias Transport = @Sendable (URLRequest) async -> Void

    // The project token is public: it can only add events, like the website's copy.
    static let projectToken = "phc_tDMHuMqgGPMaZzm3JeKNE99tisGp9k5HdCTDeEqZZd86"
    static let endpoint = URL(string: "https://us.i.posthog.com/i/v0/e/")!

    private enum Key {
        static let enabled = "shareUsageData"
        static let id = "usageAnalyticsID"
        static let lastActiveDay = "usageLastActiveDay"
        static let lastVersion = "usageLastVersion"
    }

    private let defaults: UserDefaults
    private let transport: Transport?
    private let version: String

    /// A nil transport (tests without a capture, demo folders) never sends anything.
    init(defaults: UserDefaults, transport: Transport?, version: String = UpdateChecker.currentVersion) {
        self.defaults = defaults
        self.transport = transport
        self.version = version
    }

    static func network(_ session: URLSession) -> Transport {
        { request in _ = try? await session.data(for: request) }
    }

    /// On unless the person turned it off in Settings.
    var enabled: Bool { defaults.object(forKey: Key.enabled) as? Bool ?? true }
    private var distinctID: String? { defaults.string(forKey: Key.id) }

    func setEnabled(_ on: Bool) {
        defaults.set(on, forKey: Key.enabled)
        if on {
            ensureID()
        } else {
            for key in [Key.id, Key.lastActiveDay] { defaults.removeObject(forKey: key) }
        }
    }

    private func ensureID() {
        guard enabled, distinctID == nil else { return }
        defaults.set(UUID().uuidString.lowercased(), forKey: Key.id)
        defaults.set(version, forKey: Key.lastVersion)
        capture(.firstSeen)
    }

    /// Called on launch and on each tick: counts the day once and notices a new version.
    func recordActive(on day: String) {
        let previous = defaults.string(forKey: Key.lastVersion)
        defaults.set(version, forKey: Key.lastVersion)
        guard enabled else { return }
        ensureID()
        if let previous, previous != version { capture(.appUpdated, extra: ["previous_version": previous]) }
        guard defaults.string(forKey: Key.lastActiveDay) != day else { return }
        defaults.set(day, forKey: Key.lastActiveDay)
        capture(.appActive)
    }

    func capture(_ event: Event) { capture(event, extra: [:]) }

    private func capture(_ event: Event, extra: [String: String]) {
        guard enabled, let transport, let id = distinctID else { return }
        var properties: [String: Any] = [
            "$lib": "pocket-mac",
            "$process_person_profile": false,
            "$geoip_disable": true,
            "app_version": version,
            "os_version": Self.osVersion,
            "language": Locale.current.language.languageCode?.identifier ?? "unknown",
        ]
        for (key, value) in extra { properties[key] = value }
        let body: [String: Any] = [
            "api_key": Self.projectToken,
            "event": event.rawValue,
            "distinct_id": id,
            "properties": properties,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        Task.detached(priority: .utility) { await transport(request) }
    }

    private static var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion)"
    }
}
