import Foundation
import PocketCore
import XCTest
@testable import Pocket

/// A tiny stand-in for the account's pocket_* functions, behind URLProtocol.
final class MockAccount: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var txs: [[String: Any]] = []
    nonisolated(unsafe) static var presets: [[String: Any]] = []
    nonisolated(unsafe) static var failure: URLError.Code?
    nonisolated(unsafe) static var calls: [String] = []
    nonisolated(unsafe) static var rules: [[String: Any]] = []
    nonisolated(unsafe) static var setUpKey: String?
    nonisolated(unsafe) static var hosts: Set<String> = []
    nonisolated(unsafe) static var subscriptionTracking = true
    static let key = "test-key"

    static func reset(balance: Double) {
        txs = [["id": UUID().uuidString, "amount": balance, "label": "Starting balance", "occurred_on": "2026-10-11",
                "created_at": "2026-10-11T10:00:00.123456+00:00", "category": "start"]]
        presets = []
        failure = nil
        calls = []
        rules = []
        setUpKey = nil
        hosts = []
        subscriptionTracking = true
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let fn = request.url!.lastPathComponent
        let body = request.httpBody ?? request.httpBodyStream.map(Self.read) ?? Data()
        let args = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
        Self.calls.append(fn)
        Self.hosts.insert(request.url?.host ?? "")
        if let code = Self.failure {
            client?.urlProtocol(self, didFailWithError: URLError(code))
            return
        }
        if fn == "pocket_setup" {
            if Self.setUpKey != nil || !Self.txs.isEmpty { return respond(200, ["error": "already_set_up"]) }
            Self.setUpKey = args["p_key"] as? String
            return respond(200, ["ok": true])
        }
        if fn != "pocket_pair_finish" && args["k"] as? String != Self.key && (Self.setUpKey == nil || args["k"] as? String != Self.setUpKey) {
            return respond(401, ["code": "28000", "message": "bad key"])
        }
        switch fn {
        case "pocket_state":
            respond(200, ["transactions": Self.txs, "recurring": Self.rules, "upcoming": [Any](), "presets": Self.presets, "subscription_tracking": Self.subscriptionTracking])
        case "pocket_add":
            let row: [String: Any] = ["id": UUID().uuidString, "amount": args["p_amount"]!, "label": args["p_label"]!,
                                      "occurred_on": args["p_on"]!, "created_at": "2026-10-12T15:00:00.5+00:00",
                                      "category": args["p_category"] ?? NSNull()]
            Self.txs.insert(row, at: 0)
            respond(200, row)
        case "pocket_update":
            if let i = Self.txs.firstIndex(where: { $0["id"] as? String == args["p_id"] as? String }) {
                Self.txs[i]["amount"] = args["p_amount"]; Self.txs[i]["label"] = args["p_label"]
            }
            respond(200, [:])
        case "pocket_delete":
            Self.txs.removeAll { $0["id"] as? String == args["p_id"] as? String }
            respond(204, nil)
        case "pocket_recurring_add":
            let id = UUID().uuidString
            Self.rules.append(["id": id, "amount": args["p_amount"]!, "label": args["p_label"]!, "cadence": args["p_cadence"]!,
                               "active": true, "auto": args["p_auto"] ?? true, "category": args["p_category"] ?? NSNull(),
                               "next_on": args["p_start"]!, "remaining": args["p_times"] ?? NSNull()])
            Self.rules[Self.rules.count - 1]["subscription"] = args["p_subscription"]
            respond(200, ["id": id])
        case "pocket_subscription_set":
            if let i = Self.rules.firstIndex(where: { $0["id"] as? String == args["p_id"] as? String }) {
                Self.rules[i]["subscription"] = args["p_subscription"]
            }
            respond(204, nil)
        case "pocket_recurring_set_active":
            if let i = Self.rules.firstIndex(where: { $0["id"] as? String == args["p_id"] as? String }) { Self.rules[i]["active"] = args["p_active"] }
            respond(204, nil)
        case "pocket_preset_save":
            let id = UUID().uuidString
            Self.presets.append(["id": id, "label": args["p_label"]!, "sign": args["p_sign"]!, "amount": args["p_amount"] ?? NSNull(),
                                 "category": args["p_category"] ?? NSNull()])
            respond(200, ["id": id])
        case "pocket_pair_finish":
            respond(200, args["p_code"] as? String == "123456" ? ["token": Self.key] : ["error": "wrong"])
        default:
            respond(404, ["message": "unknown"])
        }
    }

    private func respond(_ status: Int, _ json: Any?) {
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        if let json { client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: json)) }
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func read(_ stream: InputStream) -> Data {
        stream.open(); defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }

    static var serverBalance: Cents { txs.reduce(0) { $0 + ServerState.cents(($1["amount"] as? Double) ?? 0) } }
}

@MainActor
final class AccountSyncTests: XCTestCase {
    private func makeStore(_ keyStore: AccountKeyStore = .memory()) throws -> Store {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pocket-sync-\(UUID())")
        let suite = "pocket-sync-tests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(false, forKey: "reminders")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockAccount.self]
        return Store(directory: directory, defaults: defaults, servicesEnabled: false,
                     session: URLSession(configuration: config), keyStore: keyStore)
    }

    func testConnectBringsTheAccountBalanceAndKeepsACopyOnThisMac() async throws {
        MockAccount.reset(balance: -69.08)
        let store = try makeStore()
        XCTAssertFalse(store.connected)
        try await store.connect(code: "123456")
        XCTAssertTrue(store.connected)
        XCTAssertTrue(store.onboarded)
        XCTAssertEqual(store.balance, -6908)
        XCTAssertTrue(store.fileURL.lastPathComponent == "account-ledger.json")
        let disk = try JSONDecoder.iso.decode(Ledger.self, from: Data(contentsOf: store.fileURL))
        XCTAssertEqual(disk.balance, -6908)
    }

    func testWrongCodeAndRemovedAccessDoNotConnect() async throws {
        MockAccount.reset(balance: 10)
        let store = try makeStore()
        do { try await store.connect(code: "000000"); XCTFail("should not connect") } catch {}
        do { try await store.connect(key: "revoked"); XCTFail("should not connect") } catch {}
        XCTAssertFalse(store.connected)
    }

    func testOfflineEntryWaitsThenSyncsExactlyOnce() async throws {
        MockAccount.reset(balance: 100)
        let store = try makeStore()
        try await store.connect(key: MockAccount.key)
        MockAccount.failure = .notConnectedToInternet
        XCTAssertNotNil(store.addEntry(cents: -650, label: "Coffee", day: .today, category: "food"))
        await store.syncNow()
        XCTAssertEqual(store.balance, 9350, "the Mac shows the change right away")
        XCTAssertEqual(store.outbox.count, 1)
        XCTAssertEqual(store.syncState, .offline)
        MockAccount.failure = nil
        await store.syncNow()
        XCTAssertTrue(store.outbox.isEmpty)
        XCTAssertEqual(MockAccount.serverBalance, 9350)
        XCTAssertEqual(MockAccount.txs.count, 2)
        XCTAssertEqual(store.balance, 9350)
        await store.syncNow()
        XCTAssertEqual(MockAccount.txs.count, 2, "syncing again never re-sends")
    }

    func testEditingAnEntryBeforeItSyncsUpdatesTheAccountCopy() async throws {
        MockAccount.reset(balance: 100)
        let store = try makeStore()
        try await store.connect(key: MockAccount.key)
        MockAccount.failure = .notConnectedToInternet
        let id = try XCTUnwrap(store.addEntry(cents: -650, label: "Coffee", day: .today, category: "food"))
        var entry = try XCTUnwrap(store.ledger.entries.first { $0.id == id })
        entry.cents = -800
        XCTAssertTrue(store.updateEntry(entry))
        MockAccount.failure = nil
        await store.syncNow()
        XCTAssertTrue(store.outbox.isEmpty)
        XCTAssertEqual(MockAccount.serverBalance, 9200)
        XCTAssertEqual(store.balance, 9200)
    }

    func testTimedOutRequestWaitsForReviewInsteadOfPostingTwice() async throws {
        MockAccount.reset(balance: 100)
        let store = try makeStore()
        try await store.connect(key: MockAccount.key)
        MockAccount.failure = .timedOut
        _ = store.addEntry(cents: -1000, label: "Boost", day: .today, category: nil)
        await store.syncNow()
        XCTAssertEqual(store.outbox.first?.needsReview, true)
        MockAccount.failure = nil
        await store.syncNow()
        XCTAssertEqual(MockAccount.txs.count, 1, "not re-sent on its own")
        XCTAssertEqual(store.balance, 10000, "the Mac shows the account's balance while it waits for review")
        store.retry(try XCTUnwrap(store.outbox.first).id)
        await store.syncNow()
        XCTAssertEqual(MockAccount.txs.count, 2)
        XCTAssertEqual(store.balance, 9000)
    }

    func testChangesFromThePhoneArrive() async throws {
        MockAccount.reset(balance: 100)
        let store = try makeStore()
        try await store.connect(key: MockAccount.key)
        MockAccount.txs.insert(["id": UUID().uuidString, "amount": -4.99, "label": "Valorant", "occurred_on": Day.today.iso,
                                "created_at": "2026-10-12T16:00:00+00:00", "category": "games"], at: 0)
        await store.syncNow()
        XCTAssertEqual(store.balance, 9501)
        XCTAssertEqual(store.ledger.sortedEntries.first?.label, "Valorant")
    }

    func testKeyIsRememberedAndDisconnectKeepsALocalCopy() async throws {
        MockAccount.reset(balance: -69.08)
        let keys = AccountKeyStore.memory()
        let store = try makeStore(keys)
        try await store.connect(key: MockAccount.key)
        XCTAssertEqual(keys.load(), MockAccount.key)
        store.disconnect()
        XCTAssertNil(keys.load())
        XCTAssertFalse(store.connected)
        XCTAssertEqual(store.balance, -6908)
        XCTAssertEqual(store.fileURL.lastPathComponent, "ledger.json")
        let disk = try JSONDecoder.iso.decode(Ledger.self, from: Data(contentsOf: store.fileURL))
        XCTAssertEqual(disk.balance, -6908)
    }

    func testFailedAccountSaveDoesNotReportSyncedOrChangeBalance() async throws {
        MockAccount.reset(balance: 100)
        let store = try makeStore()
        try await store.connect(key: MockAccount.key)
        let lastSync = store.journal.lastSync
        let file = try Data(contentsOf: store.fileURL)
        try FileManager.default.removeItem(at: store.fileURL)
        try FileManager.default.createDirectory(at: store.fileURL, withIntermediateDirectories: false)
        MockAccount.txs[0]["amount"] = 200.0
        await store.syncNow()
        XCTAssertEqual(store.syncState, .offline)
        XCTAssertEqual(store.journal.lastSync, lastSync)
        XCTAssertEqual(store.balance, 10000)
        XCTAssertNotNil(store.saveError)
        try FileManager.default.removeItem(at: store.fileURL)
        try file.write(to: store.fileURL)
        await store.syncNow()
        XCTAssertEqual(store.balance, 20000)
        XCTAssertNil(store.saveError)
    }

    func testFailedDisconnectKeepsKeyAndAccountCopy() async throws {
        MockAccount.reset(balance: 100)
        let keys = AccountKeyStore.memory()
        let store = try makeStore(keys)
        try await store.connect(key: MockAccount.key)
        let local = store.fileURL.deletingLastPathComponent().appendingPathComponent("ledger.json")
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: false)
        XCTAssertFalse(store.disconnect())
        XCTAssertTrue(store.connected)
        XCTAssertEqual(keys.load(), MockAccount.key)
        XCTAssertEqual(store.balance, 10000)
        XCTAssertEqual(store.fileURL.lastPathComponent, "account-ledger.json")
        XCTAssertNotNil(store.saveError)
        try FileManager.default.removeItem(at: local)
        XCTAssertTrue(store.disconnect())
        XCTAssertFalse(store.connected)
        XCTAssertNil(keys.load())
        XCTAssertEqual(try JSONDecoder.iso.decode(Ledger.self, from: Data(contentsOf: local)).balance, 10000)
    }
}

extension AccountSyncTests {
    func testOlderServerRejectsMembershipChangesBeforeWritingOrQueuing() async throws {
        MockAccount.reset(balance: 100)
        MockAccount.subscriptionTracking = false
        let store = try makeStore()
        try await store.connect(key: MockAccount.key)
        let rule = Rule(cents: -999, label: "Cloud", cadence: .monthly, anchor: Day.today.adding(days: 2), subscription: true)
        XCTAssertFalse(store.addRule(rule))
        XCTAssertTrue(store.ledger.rules.isEmpty)
        XCTAssertTrue(store.outbox.isEmpty)
        XCTAssertNotNil(store.saveError)
    }

    func testSettingUpAnEmptyServerMovesThisMacsMoneyThereOnce() async throws {
        MockAccount.reset(balance: 0)
        MockAccount.txs = []
        let store = try makeStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 25_000, openAtLogin: false))
        _ = store.addEntry(cents: -1299, label: "Lunch", day: .today, category: "food")
        XCTAssertTrue(store.addRule(Rule(cents: -1549, label: "Netflix", cadence: .monthly, anchor: Day.today.adding(days: 5), category: "subscriptions")))
        XCTAssertTrue(store.addRule(Rule(cents: 50_000, label: "Client", cadence: .monthly, anchor: Day.today.adding(days: 9), active: false, auto: false)))
        store.savePreset(Preset(label: "Coffee", cents: 650, sign: -1, category: "food"))
        let mine = try XCTUnwrap(Server(url: "my-pocket.example.com", apiKey: "sb_publishable_selfhosted_key"))
        try await store.setUp(mine)
        XCTAssertTrue(store.connected)
        XCTAssertEqual(store.server, mine)
        XCTAssertEqual(MockAccount.hosts, ["my-pocket.example.com"], "only the chosen server is contacted")
        XCTAssertTrue(store.outbox.isEmpty)
        XCTAssertEqual(MockAccount.serverBalance, 23_701)
        XCTAssertEqual(store.balance, 23_701)
        XCTAssertEqual(MockAccount.txs.count, 2)
        XCTAssertEqual(MockAccount.rules.count, 2)
        XCTAssertEqual(MockAccount.rules.first { $0["label"] as? String == "Client" }?["active"] as? Bool, false)
        XCTAssertEqual(MockAccount.presets.count, 1)
        XCTAssertEqual(store.ledger.rules.count, 2)
        await store.syncNow()
        XCTAssertEqual(MockAccount.txs.count, 2, "nothing is uploaded twice")
    }

    func testSettingUpAServerThatAlreadyHasAPocketIsRefused() async throws {
        MockAccount.reset(balance: 10)
        let store = try makeStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 100, openAtLogin: false))
        do {
            try await store.setUp(try XCTUnwrap(Server(url: "https://taken.example.com", apiKey: "sb_publishable_selfhosted_key")))
            XCTFail("should refuse")
        } catch {}
        XCTAssertFalse(store.connected)
        XCTAssertEqual(store.balance, 100)
    }

    func testServerAddressesAndPhoneLinks() throws {
        XCTAssertEqual(Server(url: " abc.supabase.co/ ", apiKey: "sb_publishable_1234567890")?.url.absoluteString, "https://abc.supabase.co")
        XCTAssertNil(Server(url: "not a url", apiKey: "sb_publishable_1234567890"))
        XCTAssertNil(Server(url: "abc.supabase.co", apiKey: "short"))
        XCTAssertEqual(Server.original.webLink(code: "123456").absoluteString, "https://pocketleft.app/app/#code=123456")
        let own = try XCTUnwrap(Server(url: "abc.supabase.co", apiKey: "sb_publishable_1234567890"))
        XCTAssertEqual(own.webLink(code: nil).absoluteString,
                       "https://pocketleft.app/app/#server=https://abc.supabase.co&apikey=sb_publishable_1234567890")
    }
}

private extension JSONDecoder {
    static var iso: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}

extension AccountSyncTests {
    func testSubscriptionMembershipSyncsWithoutChangingCategoryOrAddingAnotherRule() async throws {
        MockAccount.reset(balance: 100)
        let store = try makeStore()
        try await store.connect(key: MockAccount.key)
        let rule = Rule(cents: -999, label: "Cloud", cadence: .monthly, anchor: Day.today.adding(days: 2),
                        category: "apps", subscription: true)
        XCTAssertTrue(store.addRule(rule))
        await store.syncNow()
        let saved = try XCTUnwrap(store.ledger.rules.first)
        XCTAssertTrue(saved.isSubscription)
        XCTAssertEqual(saved.category, "apps")
        XCTAssertEqual(MockAccount.rules.count, 1)
        XCTAssertEqual(store.balance, 10000)
        XCTAssertTrue(store.setSubscription(saved.id, false))
        await store.syncNow()
        XCTAssertFalse(try XCTUnwrap(store.ledger.rules.first).isSubscription)
        XCTAssertEqual(store.ledger.rules.first?.category, "apps")
        XCTAssertEqual(MockAccount.rules.count, 1)
    }
}
