import Foundation
import PocketCore
import Security

// Optional sync with a Pocket account (the web app on a phone or any computer).
// Without an account nothing leaves this Mac. With one, the account is the source of truth and this Mac
// keeps a full copy on disk: changes show instantly, wait here while offline, and go out in order.

enum AccountConfig {
    static let webURL = URL(string: "https://pocketleft.app/app/")!
    static let selfHostGuide = URL(string: "https://github.com/orlandoascanio/pocket/blob/main/SELF-HOSTING.md")!
    static let deviceName = "Mac · Pocket"
    static let syncEvery: TimeInterval = 30
}

/// Where an account lives: a Supabase project (hosted or self-hosted) with Pocket's SQL loaded.
/// Each server holds one person's Pocket.
struct Server: Codable, Equatable {
    var url: URL
    /// Publishable (anon) key: safe to ship. On its own it can only call the key-gated pocket_* functions.
    var apiKey: String

    /// The original Pocket server, used by connections made before servers were configurable.
    static let original = Server(url: URL(string: "https://upmymrrfpwnqmnaclpyt.supabase.co")!,
                                 apiKey: "sb_publishable_0QeYqlwAKI0Eit1nTB5vFw_PK1fxCaB")

    var host: String { url.host ?? url.absoluteString }

    /// Reads what someone pasted: "xyz.supabase.co" or a full https URL.
    init?(url text: String, apiKey key: String) {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while t.hasSuffix("/") { t.removeLast() }
        if !t.contains("://") { t = "https://" + t }
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let u = URL(string: t), let scheme = u.scheme, ["https", "http"].contains(scheme), u.host != nil, k.count >= 20 else { return nil }
        self.init(url: u, apiKey: k)
    }

    init(url: URL, apiKey: String) {
        self.url = url
        self.apiKey = apiKey
    }

    /// Opens the web app pointed at this server, with a pairing code filled in.
    func webLink(code: String?) -> URL {
        var parts: [String] = []
        if self != .original {
            let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+#"))
            parts.append("server=" + (url.absoluteString.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""))
            parts.append("apikey=" + (apiKey.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""))
        }
        if let code { parts.append("code=" + code) }
        return URL(string: AccountConfig.webURL.absoluteString + (parts.isEmpty ? "" : "#" + parts.joined(separator: "&")))!
    }
}

struct APIError: Error {
    let badKey: Bool
    let message: String
}

enum SyncState: Equatable {
    case syncing, ok(Date), offline, badKey
}

/// Where this Mac's access key lives. The Keychain in the app; memory in tests and previews.
struct AccountKeyStore {
    var load: () -> String?
    var save: (String?) -> Void

    static func memory(_ initial: String? = nil) -> AccountKeyStore {
        final class Box { var value: String? }
        let box = Box()
        box.value = initial
        return AccountKeyStore(load: { box.value }, save: { box.value = $0 })
    }

    static let keychain: AccountKeyStore = {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.orlandoascanio.pocket.account",
            kSecAttrAccount as String: "device-key",
        ]
        return AccountKeyStore(load: {
            var query = base
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }, save: { value in
            SecItemDelete(base as CFDictionary)
            guard let value, let data = value.data(using: .utf8) else { return }
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        })
    }()

    /// The key the older Pocket Sync app saved on this Mac, so moving over takes one click.
    static func pocketSyncKey() -> String? {
        let value = CFPreferencesCopyAppValue("key" as CFString, "com.orlandoascanio.pocket" as CFString) as? String
        return value.flatMap { $0.isEmpty ? nil : $0 }
    }
}

/// A change made on this Mac that the account hasn't confirmed yet.
struct PendingOp: Codable, Identifiable, Equatable {
    var id = UUID()
    var function: String
    var arguments: Data
    var label: String
    /// The id this Mac gave a new entry, plan or button; the account answers with its own id.
    var localID: UUID?
    /// The request may or may not have arrived (a timeout, or the account refused it). Retrying could add it twice.
    var needsReview = false
    var message: String?
}

/// Outbox and id translations, saved next to the account copy.
struct SyncJournal: Codable {
    var outbox: [PendingOp] = []
    var ids: [UUID: UUID] = [:]
    var lastSync: Date?
}

struct Device: Decodable, Identifiable, Equatable {
    let id: String
    let name: String?
    let created_at: String?
    let last_seen: String?
    let this: Bool
}

struct DevicesResponse: Decodable {
    let master: Bool
    let devices: [Device]
}

/// The account's answer to pocket_state, turned into this app's ledger.
struct ServerState: Decodable {
    struct Tx: Decodable {
        let id: UUID
        let amount: Double
        let label: String
        let occurred_on: String
        let created_at: String?
        let recurring_id: UUID?
        let category: String?
    }
    struct Recurring: Decodable {
        let id: UUID
        let amount: Double
        let label: String
        let cadence: String
        let active: Bool?
        let auto: Bool?
        let category: String?
        let next_on: String
        let remaining: Int?
        let subscription: Bool?
        let once: Bool?
    }
    struct Button: Decodable {
        let id: UUID
        let label: String
        let sign: Int
        let amount: Double?
        let category: String?
    }
    let transactions: [Tx]
    let recurring: [Recurring]
    let presets: [Button]?
    let subscription_tracking: Bool?

    static func cents(_ amount: Double) -> Cents { Int((amount * 100).rounded()) }

    private static func date(_ text: String?) -> Date? {
        guard let text else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: text) { return d }
        // Postgres sends microseconds; drop the fraction if the formatter won't take it.
        let trimmed = text.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: trimmed)
    }

    /// Repeating payments come as "next date + payments left", which is exactly a rule anchored at its next payment.
    func ledger(currency: String) -> Ledger {
        let count = transactions.count
        let entries = transactions.enumerated().compactMap { i, t -> Entry? in
            guard let day = Day(iso: t.occurred_on) else { return nil }
            // The server lists newest first; keep that order even when two share a timestamp.
            let created = ServerState.date(t.created_at) ?? Date(timeIntervalSince1970: TimeInterval(count - i))
            return Entry(id: t.id, cents: ServerState.cents(t.amount), label: t.label, day: day,
                         category: t.category, ruleID: t.recurring_id, created: created)
        }
        let rules = recurring.compactMap { r -> Rule? in
            guard let cadence = Cadence(rawValue: r.cadence), let next = Day(iso: r.next_on) else { return nil }
            return Rule(id: r.id, cents: ServerState.cents(r.amount), label: r.label, cadence: cadence, anchor: next,
                        total: r.remaining, active: r.active ?? true, auto: r.auto ?? true, category: r.category,
                        subscription: r.subscription, once: r.once)
        }
        let buttons = (presets ?? []).map {
            Preset(id: $0.id, label: $0.label, cents: $0.amount.map(ServerState.cents), sign: $0.sign, category: $0.category)
        }
        return Ledger(currency: currency, entries: entries, rules: rules, presets: buttons)
    }
}

struct AccountClient {
    let session: URLSession
    var server: Server

    func rpc(_ fn: String, _ args: [String: Any] = [:], key: String?) async throws -> Data {
        var req = URLRequest(url: server.url.appendingPathComponent("rest/v1/rpc/\(fn)"))
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue(server.apiKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body = args
        if let key { body["k"] = key }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 && fn != "pocket_setup" {
            throw APIError(badKey: false, message: "Pocket isn't set up on that server. Load Pocket's SQL first (see the self-hosting guide).")
        }
        guard (200..<300).contains(code) else {
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw APIError(badKey: obj?["code"] as? String == "28000", message: obj?["message"] as? String ?? "HTTP \(code)")
        }
        return data
    }

    /// Network failures where the request certainly never left this Mac, so sending it again can't duplicate it.
    static let safeToRetry: Set<URLError.Code> = [.notConnectedToInternet, .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost]
}
