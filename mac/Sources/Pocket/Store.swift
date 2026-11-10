import AppKit
import PocketCore
import ServiceManagement
import SwiftUI
@preconcurrency import UserNotifications

/// A change in the balance, so the pocket can react to it.
struct BalanceChange: Equatable {
    let id = UUID()
    let diff: Cents
    let outOfRed: Bool
    let intoRed: Bool
    let category: String?
    let deleted: Bool
}

/// Something the pocket should say that didn't move the balance (a plan, a skip, a pause).
struct Speech: Equatable {
    let id = UUID()
    let text: String
    let face: Face
}

/// Where a menubar click asks the main window to go.
enum WindowRequest: Equatable {
    case editEntry(UUID)
    case editRule(UUID)
    case section(AppSection)
    case newEntry(EntryDraft)
    /// Open the simple Overview composer with the amount field ready for a first expense.
    case firstEntry
    /// A quick-add button that asks for its amount: fill the Overview entry and wait for the amount.
    case quickAdd(Preset)
    case waiting
    case history
}

/// One of the daily copies kept next to the data file.
struct Backup: Identifiable, Equatable {
    let day: Day
    let url: URL
    var id: URL { url }
}

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case overview = "Overview", plan = "Plan", subscriptions = "Subscriptions", insights = "Insights", settings = "Settings"
    var id: String { rawValue }
    var title: String { self == .insights ? "Categories" : rawValue }
    var symbol: String {
        switch self {
        case .overview: "house"
        case .plan: "chart.line.uptrend.xyaxis"
        case .subscriptions: "repeat.circle"
        case .insights: "chart.bar.xaxis"
        case .settings: "gearshape"
        }
    }
}

struct EntryReceipt {
    let text: String
    let target: WindowRequest
}

/// Owns the ledger. Without an account everything lives in one JSON file on this Mac.
/// With an account, this Mac keeps a full copy in its own file and syncs it (see AccountSync.swift).
@MainActor
final class Store: ObservableObject {
    @Published private(set) var ledger: Ledger
    @Published private(set) var today = Day.today
    @Published private(set) var change: BalanceChange?
    @Published private(set) var speech: Speech?
    @Published var windowRequest: WindowRequest?
    @Published private(set) var saveError: String?
    @Published private(set) var loadError: String?
    @Published private(set) var receipt: EntryReceipt?
    @Published var onboarded: Bool { didSet { defaults.set(onboarded, forKey: "onboarded") } }
    @Published var range: Int { didSet { defaults.set(range, forKey: "range") } }
    /// Whether the forecast counts everyday spending, not only scheduled payments.
    @Published var includeEveryday: Bool { didSet { defaults.set(includeEveryday, forKey: "includeEveryday") } }
    @Published var reminders: Bool {
        didSet {
            defaults.set(reminders, forKey: "reminders")
            reminderMessage = nil
            if reminders { requestNotificationPermission() }
            scheduleReminders()
        }
    }
    @Published var subscriptionReminders: Bool {
        didSet {
            defaults.set(subscriptionReminders, forKey: "subscriptionReminders")
            reminderMessage = nil
            if subscriptionReminders { requestNotificationPermission() }
            scheduleReminders()
        }
    }
    @Published private(set) var reminderMessage: String?
    /// The one-time "Know someone who'd like Pocket?" note: nil until it's earned, then "due", then "done" for good.
    @Published private(set) var sharePrompt: String? { didSet { defaults.set(sharePrompt, forKey: "sharePrompt") } }
    var showSharePrompt: Bool { sharePrompt == "due" }
    @Published private(set) var sendingTestReminder = false
    var notificationServicesAvailable: Bool { reminderClient != nil }

    /// The ledger file in use: the local one, or this Mac's copy of the account.
    var fileURL: URL { accountKey == nil ? localURL : accountURL }
    private let localURL: URL
    private let accountURL: URL
    private let journalURL: URL
    private let defaults: UserDefaults
    private let servicesEnabled: Bool
    private let reminderClient: ReminderClient?
    private let reminderNow: () -> Date
    private var reminderRefreshNeeded = false
    private var reminderTask: Task<Void, Never>?
    private var timer: Timer?
    private var syncTimer: Timer?

    // MARK: account state
    private let keyStore: AccountKeyStore
    private let session: URLSession
    /// The server this Mac syncs with (or last used, so reconnecting starts there).
    @Published private(set) var server: Server
    private var client: AccountClient { AccountClient(session: session, server: server) }
    @Published private(set) var accountKey: String?
    @Published private(set) var syncState: SyncState = .offline
    @Published private(set) var journal = SyncJournal()
    private var syncInFlight = false
    private var syncAgain = false
    private var subscriptionSyncAvailable = false
    var connected: Bool { accountKey != nil }
    /// Changes still on their way to the account, and ones that need a look before retrying.
    var outbox: [PendingOp] { journal.outbox }

    var money: Money { Money(currency: ledger.currency) }
    var balance: Cents { ledger.balance }
    var waiting: [Occurrence] { ledger.waiting(today: today) }
    /// What's usually spent on unscheduled things, from recent weeks of history.
    var everyday: EverydaySpending? { ledger.everydaySpending(today: today) }
    /// Everyday spending the forecast counts, in cents a day.
    var forecastEveryday: Cents { includeEveryday ? everyday?.perDay ?? 0 : 0 }
    var projection: Projection { ledger.project(today: today, days: range, everyday: forecastEveryday) }
    var monthsLeft: Double? { ledger.monthsLeft(everyday: forecastEveryday) }
    var menuTitle: String {
        if loadError != nil { return "Pocket ⚠︎" }
        guard onboarded else { return "Pocket" }
        return money.string(balance) + (syncState == .badKey ? " ⚠︎" : "")
    }

    var spentThisMonth: Cents { ledger.summary(today.yearMonth).spent }
    var hasRecordedEntries: Bool { ledger.entries.contains { $0.category != Categories.start } }

    var runway: Projection.Runway? {
        let everyday = forecastEveryday
        let p = ledger.project(today: today, days: 91, everyday: everyday)
        if p.steps.isEmpty && everyday == 0 && balance >= 0 { return nil }
        return p.runway
    }

    init(directory: URL? = nil, defaults suppliedDefaults: UserDefaults? = nil, servicesEnabled: Bool = true,
         session: URLSession = .shared, keyStore: AccountKeyStore? = nil,
         reminderClient: ReminderClient? = nil, reminderNow: @escaping () -> Date = Date.init) {
        // POCKET_DATA_DIR (development only) points the app at a separate folder, e.g. demo data.
        let env = ProcessInfo.processInfo.environment
        self.servicesEnabled = servicesEnabled && directory == nil && env["POCKET_DATA_DIR"] == nil
        // An explicit recording opt-in enables only notifications, keeping demo data, login and keys isolated.
        let notificationsEnabled = servicesEnabled && directory == nil
            && (env["POCKET_DATA_DIR"] == nil || env["POCKET_DEMO_NOTIFICATIONS"] == "1")
        self.reminderClient = reminderClient ?? (notificationsEnabled ? .system : nil)
        self.reminderNow = reminderNow
        self.defaults = suppliedDefaults ?? env["POCKET_DATA_DIR"].flatMap { UserDefaults(suiteName: "com.orlandoascanio.pocket.preview." + URL(fileURLWithPath: $0).lastPathComponent) } ?? .standard
        let dir = directory ?? env["POCKET_DATA_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Pocket", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        localURL = dir.appendingPathComponent("ledger.json")
        accountURL = dir.appendingPathComponent("account-ledger.json")
        journalURL = dir.appendingPathComponent("account-sync.json")
        // The real Keychain only for the installed app; tests and demo folders keep keys in memory.
        self.keyStore = keyStore ?? (directory == nil && env["POCKET_DATA_DIR"] == nil ? .keychain : .memory())
        self.session = session
        server = self.defaults.data(forKey: "accountServer").flatMap { try? JSONDecoder().decode(Server.self, from: $0) } ?? .original
        let key = self.keyStore.load()
        accountKey = key
        let fresh = Ledger(currency: Locale.current.currency?.identifier ?? "USD")
        let loaded: Ledger
        let initialLoadError: String?
        do {
            loaded = try Store.read(key == nil ? localURL : accountURL) ?? fresh
            initialLoadError = nil
        }
        catch {
            loaded = fresh
            initialLoadError = "Couldn't open your saved data: \(error.localizedDescription)"
        }
        ledger = loaded
        if key != nil {
            journal = (try? Data(contentsOf: journalURL)).flatMap { try? Store.decoder().decode(SyncJournal.self, from: $0) } ?? SyncJournal()
        }
        let hasSavedData = !loaded.entries.isEmpty || !loaded.rules.isEmpty
        let wasOnboarded = defaults.bool(forKey: "onboarded")
        onboarded = wasOnboarded || hasSavedData || key != nil || initialLoadError != nil
        let r = defaults.integer(forKey: "range")
        range = [30, 91, 182, 365].contains(r) ? r : 91
        includeEveryday = defaults.object(forKey: "includeEveryday") as? Bool ?? true
        reminders = defaults.object(forKey: "reminders") as? Bool ?? true
        subscriptionReminders = defaults.bool(forKey: "subscriptionReminders")
        sharePrompt = defaults.string(forKey: "sharePrompt")
        loadError = initialLoadError
        saveError = initialLoadError

        if self.servicesEnabled && env["POCKET_LOGIN"] == "off" { try? SMAppService.mainApp.unregister() }
        // Repeating money is logged on its day even if the app just sits in the menubar.
        if self.servicesEnabled {
            timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            let nc = NSWorkspace.shared.notificationCenter
            nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.syncNow() }
            }
            // Changes made on the phone show up here within half a minute.
            syncTimer = Timer.scheduledTimer(withTimeInterval: AccountConfig.syncEvery, repeats: true) { [weak self] _ in
                Task { @MainActor in await self?.syncNow() }
            }
        }
        if notificationsEnabled {
            NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.scheduleReminders() }
            }
        }
        tick()
    }

    // MARK: storage

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    private static func read(_ url: URL) throws -> Ledger? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let ledger = try decoder().decode(Ledger.self, from: Data(contentsOf: url))
        try ledger.validate()
        return ledger
    }

    private func persist(_ candidate: Ledger, replacingUnreadableData: Bool = false) -> Bool {
        guard loadError == nil || replacingUnreadableData else { saveError = loadError; return false }
        do {
            // An unreadable file is set aside rather than overwritten, and never enters the daily backups.
            if loadError != nil { try setAsideUnreadableFile() } else { backupOncePerDay() }
            try Store.encoder().encode(candidate).write(to: fileURL, options: .atomic)
            loadError = nil
            saveError = nil
            return true
        } catch {
            saveError = "Couldn't save: \(error.localizedDescription)"
            return false
        }
    }

    func retryLoadingData() {
        do {
            guard let saved = try Store.read(fileURL) else { throw CocoaError(.fileReadNoSuchFile) }
            ledger = saved
            loadError = nil
            saveError = nil
            tick()
        } catch {
            loadError = "Couldn't open your saved data: \(error.localizedDescription)"
            saveError = loadError
        }
    }

    private var backupsDirectory: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
    }

    /// The daily copies, newest first.
    var backups: [Backup] {
        let files = (try? FileManager.default.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: nil)) ?? []
        return files.compactMap { url -> Backup? in
            let name = url.deletingPathExtension().lastPathComponent
            guard url.pathExtension == "json", name.hasPrefix("ledger-"),
                  let day = Day(iso: String(name.dropFirst("ledger-".count))) else { return nil }
            return Backup(day: day, url: url)
        }
        .sorted { $0.day > $1.day }
    }

    func showBackupsInFinder() {
        let dir = backupsDirectory
        if FileManager.default.fileExists(atPath: dir.path) { NSWorkspace.shared.open(dir) }
        else { NSWorkspace.shared.activateFileViewerSelecting([fileURL]) }
    }

    /// Replaces the local data with one of the daily copies (local mode only, like Import).
    func restore(_ backup: Backup) throws { try importFile(backup.url) }

    /// Keeps the file that couldn't be opened, next to it, before anything replaces it.
    private func setAsideUnreadableFile() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let name = "\(fileURL.deletingPathExtension().lastPathComponent) (couldn't open) \(stamp).json"
        try fm.copyItem(at: fileURL, to: fileURL.deletingLastPathComponent().appendingPathComponent(name))
    }

    /// Keeps a copy per day for the last 7 days, next to the data file.
    private func backupOncePerDay() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }
        let dir = backupsDirectory
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appendingPathComponent("ledger-\(Day.today.iso).json")
        guard !fm.fileExists(atPath: target.path) else { return }
        try? fm.copyItem(at: fileURL, to: target)
        let old = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in old.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).dropFirst(7) {
            try? fm.removeItem(at: url)
        }
    }

    // MARK: changes

    /// Logs anything that came due (new day, wake from sleep, every 15 minutes).
    func tick() {
        today = .today
        var candidate = ledger
        let logged = candidate.postDue(today: today)
        if !logged.isEmpty {
            let before = ledger.balance
            if persist(candidate) {
                ledger = candidate
                announce(diff: ledger.balance - before, before: before, category: logged.last?.category, deleted: false)
            }
        }
        scheduleReminders()
        if connected { Task { await syncNow() } }
    }

    @discardableResult
    private func mutate(deleted: Bool = false, category: String? = nil, _ body: (inout Ledger) -> Void) -> Bool {
        receipt = nil
        let before = ledger.balance
        var candidate = ledger
        body(&candidate)
        candidate.postDue(today: today)
        guard persist(candidate) else { return false }
        ledger = candidate
        let diff = ledger.balance - before
        if diff != 0 { announce(diff: diff, before: before, category: category, deleted: deleted) }
        scheduleReminders()
        return true
    }

    private func announce(diff: Cents, before: Cents, category: String?, deleted: Bool) {
        let after = before + diff
        change = BalanceChange(diff: diff, outOfRed: before < 0 && after >= 0, intoRed: before >= 0 && after < 0,
                               category: category, deleted: deleted)
    }

    func say(_ text: String, face: Face) { speech = Speech(text: text, face: face) }

    // MARK: actions

    @discardableResult
    func addEntry(cents: Cents, label: String, day: Day, category: String?, preset: Preset? = nil) -> UUID? {
        let entry = Entry(cents: cents, label: label, day: day, category: category)
        guard mutate(category: category, {
            $0.add(entry)
            if let preset { $0.presets.append(preset) }
        }) else { return nil }
        send("pocket_add", ["p_amount": dollars(cents), "p_label": label, "p_on": day.iso, "p_category": category ?? NSNull()],
             label: label, localID: entry.id)
        if let preset {
            send("pocket_preset_save", ["p_label": preset.label, "p_sign": preset.sign, "p_amount": preset.cents.map(dollars) ?? NSNull(),
                                        "p_category": preset.category ?? ""], label: preset.label, localID: preset.id)
        }
        receipt = EntryReceipt(text: "Added \(money.string(cents, signed: true)) · \(label)", target: .editEntry(entry.id))
        earnSharePrompt(gotPaid: false)
        return entry.id
    }

    @discardableResult
    func updateEntry(_ entry: Entry) -> Bool {
        guard mutate(category: entry.category, { $0.update(entry) }) else { return false }
        send("pocket_update", ["p_id": entry.id.uuidString, "p_amount": dollars(entry.cents), "p_label": entry.label,
                               "p_on": entry.day.iso, "p_category": entry.category ?? ""], label: entry.label)
        return true
    }

    @discardableResult
    func deleteEntry(_ id: UUID) -> Bool {
        let label = ledger.entries.first { $0.id == id }?.label ?? "Entry"
        guard mutate(deleted: true, { $0.removeEntry(id) }) else { return false }
        send("pocket_delete", ["p_id": id.uuidString], label: label)
        return true
    }

    @discardableResult
    func addRule(_ rule: Rule) -> Bool {
        guard canSaveSubscription(rule.subscription) else { return false }
        let before = ledger.balance
        guard mutate(category: rule.category, { $0.addRule(rule, today: today) }) else { return false }
        var args: [String: Any] = ["p_amount": dollars(rule.cents), "p_label": rule.label, "p_cadence": rule.cadence.rawValue,
                                   "p_start": rule.anchor.iso, "p_today": today.iso, "p_category": rule.category ?? NSNull(), "p_auto": rule.auto]
        if let total = rule.total { args["p_times"] = total }
        if let subscription = rule.subscription { args["p_subscription"] = subscription }
        send("pocket_recurring_add", args, label: rule.label, localID: rule.id)
        receipt = EntryReceipt(text: "Scheduled \(money.string(rule.cents, signed: true)) · \(rule.label)", target: .editRule(rule.id))
        if ledger.balance == before {
            say(Lines.shared.line(rule.cents > 0 ? "waiting" : "planned"), face: rule.cents > 0 ? .hope : .happy)
        }
        if !rule.auto { requestNotificationPermission() }
        return true
    }

    @discardableResult
    func updateRule(_ id: UUID, cents: Cents, label: String, cadence: Cadence, next: Day, left: Int?,
                    category: String?, auto: Bool, subscription: Bool? = nil, once: Bool? = nil) -> Bool {
        guard canSaveSubscription(subscription) else { return false }
        guard mutate(category: category, {
            $0.updateRule(id, cents: cents, label: label, cadence: cadence, next: next, left: left,
                          category: category, auto: auto, today: today, subscription: subscription, once: once)
        }) else { return false }
        var args: [String: Any] = ["p_id": id.uuidString, "p_amount": dollars(cents), "p_label": label, "p_cadence": cadence.rawValue,
                                   "p_next": next.iso, "p_today": today.iso, "p_category": category ?? "", "p_auto": auto]
        if let left { args["p_left"] = left }
        if let subscription { args["p_subscription"] = subscription }
        send("pocket_recurring_update", args, label: label)
        return true
    }

    @discardableResult
    func setSubscription(_ id: UUID, _ included: Bool) -> Bool {
        guard canSaveSubscription(included) else { return false }
        guard let rule = ledger.rules.first(where: { $0.id == id }), rule.cents < 0, !rule.isOnce, !rule.finished else { return false }
        guard mutate({ ledger in
            guard let index = ledger.rules.firstIndex(where: { $0.id == id }) else { return }
            ledger.rules[index].subscription = included
        }) else { return false }
        send("pocket_subscription_set", ["p_id": id.uuidString, "p_subscription": included], label: rule.label)
        return true
    }

    private func canSaveSubscription(_ membership: Bool?) -> Bool {
        guard connected && membership != nil && !subscriptionSyncAvailable else { return true }
        saveError = "This sync server needs the Subscriptions update before it can save subscription changes. Update its SQL, then sync again."
        return false
    }

    @discardableResult
    func removeRule(_ id: UUID) -> Bool {
        let label = ledger.rules.first { $0.id == id }?.label ?? "Payment"
        guard mutate({ $0.removeRule(id) }) else { return false }
        send("pocket_recurring_delete", ["p_id": id.uuidString], label: label)
        say(Lines.shared.line("deleted"), face: .oof)
        return true
    }

    @discardableResult
    func settle(_ occurrence: Occurrence, cents: Cents, on day: Day) -> Bool {
        guard let rule = ledger.rules.first(where: { $0.id == occurrence.ruleID }),
              occurrence.isNext, rule.active, !rule.finished, rule.next == occurrence.day else { return false }
        guard mutate(category: occurrence.category, { $0.settle(occurrence.ruleID, cents: cents, on: day, today: today) }) else { return false }
        send("pocket_recurring_settle", ["p_id": occurrence.ruleID.uuidString, "p_amount": dollars(cents), "p_on": day.iso,
                                         "p_today": today.iso], label: occurrence.label)
        earnSharePrompt(gotPaid: cents > 0)
        return true
    }

    /// Pocket suggests sharing once, right after it has proved useful: the first "Got it" on money
    /// that was expected, or about 30 entries recorded over at least two weeks. Never during first run.
    private func earnSharePrompt(gotPaid: Bool) {
        guard sharePrompt == nil, onboarded else { return }
        let recorded = ledger.entries.filter { $0.category != Categories.start }
        let since = recorded.map(\.created).min() ?? .now
        if gotPaid || (recorded.count >= 30 && Date.now.timeIntervalSince(since) >= 14 * 86_400) { sharePrompt = "due" }
    }

    func shareFromPrompt() {
        SharePocket.show()
        sharePrompt = "done"
    }

    func dismissSharePrompt() { sharePrompt = "done" }

    @discardableResult
    func skip(_ occurrence: Occurrence) -> Bool {
        guard let rule = ledger.rules.first(where: { $0.id == occurrence.ruleID }),
              occurrence.isNext, rule.active, !rule.finished, rule.next == occurrence.day else { return false }
        guard mutate({ $0.skip(occurrence.ruleID) }) else { return false }
        send("pocket_recurring_skip", ["p_id": occurrence.ruleID.uuidString], label: occurrence.label)
        say(Lines.shared.line("skip"), face: .oof)
        return true
    }

    @discardableResult
    func setActive(_ id: UUID, _ active: Bool) -> Bool {
        guard mutate({ $0.setActive(id, active, today: today) }) else { return false }
        send("pocket_recurring_set_active", ["p_id": id.uuidString, "p_active": active, "p_today": today.iso],
             label: ledger.rules.first { $0.id == id }?.label ?? "Payment")
        say(Lines.shared.line(active ? "resumed" : "paused"), face: active ? .joy : .sleep)
        return true
    }

    @discardableResult
    func savePreset(_ preset: Preset) -> Bool {
        let exists = ledger.presets.contains { $0.id == preset.id }
        guard mutate({
            if let i = $0.presets.firstIndex(where: { $0.id == preset.id }) { $0.presets[i] = preset } else { $0.presets.append(preset) }
        }) else { return false }
        var args: [String: Any] = ["p_label": preset.label, "p_sign": preset.sign, "p_amount": preset.cents.map(dollars) ?? NSNull(),
                                   "p_category": preset.category ?? ""]
        if exists { args["p_id"] = preset.id.uuidString }
        send("pocket_preset_save", args, label: preset.label, localID: exists ? nil : preset.id)
        return true
    }

    func deletePreset(_ id: UUID) {
        let label = ledger.presets.first { $0.id == id }?.label ?? "Button"
        guard mutate({ $0.presets.removeAll { $0.id == id } }) else { return }
        send("pocket_preset_delete", ["p_id": id.uuidString], label: label)
    }
    /// An entry that could become a quick-add button: logged by hand and not already a button.
    func canSaveAsPreset(_ entry: Entry) -> Bool {
        entry.ruleID == nil && entry.category != Categories.start
            && !ledger.presets.contains { $0.label.caseInsensitiveCompare(entry.label) == .orderedSame && ($0.sign < 0) == (entry.cents < 0) }
    }

    /// Turns a logged entry into a quick-add button with the same amount, description and category.
    @discardableResult
    func saveAsPreset(_ entryID: UUID) -> Bool {
        guard let e = ledger.entries.first(where: { $0.id == entryID }), canSaveAsPreset(e) else { return false }
        let preset = Preset(label: e.label, cents: abs(e.cents), sign: e.cents < 0 ? -1 : 1, category: e.category)
        guard savePreset(preset) else { return false }
        let index = ledger.presets.firstIndex { $0.id == preset.id } ?? 9
        receipt = EntryReceipt(text: "“\(e.label)” is now a quick-add button" + (index < 9 ? " · ⌘\(index + 1)" : ""),
                               target: .section(.settings))
        say(Lines.shared.line("planned"), face: .happy)
        return true
    }

    /// A quick-add button from anywhere (the Quick Add menu): fixed amounts log at once, the rest ask.
    func useQuickAdd(_ preset: Preset) {
        guard loadError == nil else { return }
        if let cents = preset.cents {
            addEntry(cents: preset.sign * cents, label: preset.label, day: today, category: preset.category)
        } else {
            windowRequest = .quickAdd(preset)
        }
    }

    func movePresets(from: IndexSet, to: Int) { mutate { $0.presets.move(fromOffsets: from, toOffset: to) } }
    func setCurrency(_ code: String) { mutate { $0.currency = code } }

    @discardableResult
    func start(currency: String, cents: Cents, openAtLogin: Bool) -> Bool {
        guard !onboarded else { return false }
        guard mutate({
            $0.currency = currency
            if cents != 0 { $0.add(Entry(cents: cents, label: "Starting balance", day: today, category: Categories.start)) }
        }) else { return false }
        if openAtLogin && servicesEnabled { try? SMAppService.mainApp.register() }
        onboarded = true
        return true
    }

    // MARK: data

    func export(to url: URL) throws {
        try Store.encoder().encode(ledger).write(to: url, options: .atomic)
    }

    /// Entries as a CSV spreadsheet (all of them, or what History shows).
    func exportCSV(_ entries: [Entry], to url: URL) throws {
        try Data(CSV.entries(entries, currency: ledger.currency).utf8).write(to: url, options: .atomic)
    }

    func importFile(_ url: URL) throws {
        guard !connected else { throw CocoaError(.featureUnsupported) }
        let data = try Data(contentsOf: url)
        let l = try Store.decoder().decode(Ledger.self, from: data)
        try l.validate()
        var candidate = l
        candidate.postDue(today: today)
        guard persist(candidate, replacingUnreadableData: true) else { throw CocoaError(.fileWriteUnknown) }
        ledger = candidate
        receipt = nil
        scheduleReminders()
        onboarded = true
    }

    func eraseEverything() {
        guard !connected else { return }
        let currency = ledger.currency
        let empty = Ledger(currency: currency)
        guard persist(empty, replacingUnreadableData: true) else { return }
        ledger = empty
        receipt = nil
        scheduleReminders()
        onboarded = false
    }

    // MARK: account

    private func dollars(_ cents: Cents) -> Double { Double(cents) / 100 }

    /// Queues a change for the account (only while connected) and starts sending it.
    private func send(_ fn: String, _ args: [String: Any], label: String, localID: UUID? = nil, start: Bool = true) {
        guard connected, let data = try? JSONSerialization.data(withJSONObject: args) else { return }
        journal.outbox.append(PendingOp(function: fn, arguments: data, label: label, localID: localID))
        saveJournal()
        if start { Task { await syncNow() } }
    }

    private func saveJournal() {
        guard connected else { return }
        try? Store.encoder().encode(journal).write(to: journalURL, options: .atomic)
    }

    /// Sends what's waiting, in order, then replaces this Mac's copy with the account's.
    /// While anything can still be retried, the copy here (with those changes in it) is kept instead.
    func syncNow() async {
        guard let key = accountKey else { return }
        if syncInFlight { syncAgain = true; return }
        syncInFlight = true
        defer { syncInFlight = false }
        repeat {
            syncAgain = false
            if case .ok = syncState {} else { syncState = .syncing }
            do {
                try await flush(key)
                guard key == accountKey else { return }
                guard !journal.outbox.contains(where: { !$0.needsReview }) else { syncState = .offline; return }
                let data = try await client.rpc("pocket_state", ["p_today": Day.today.iso, "p_days": 1], key: key)
                let state = try Store.decoder().decode(ServerState.self, from: data)
                subscriptionSyncAvailable = state.subscription_tracking == true
                guard key == accountKey else { return }
                // A change made while the request was out goes first; the next round picks up the result.
                if journal.outbox.contains(where: { !$0.needsReview }) { syncAgain = true; continue }
                guard adopt(state.ledger(currency: ledger.currency)) else { syncState = .offline; return }
                journal.lastSync = Date()
                if journal.outbox.isEmpty { journal.ids = [:] }
                saveJournal()
                syncState = .ok(Date())
            } catch let e as APIError where e.badKey {
                if key == accountKey { syncState = .badKey }
                return
            } catch {
                if key == accountKey { syncState = .offline }
                return
            }
        } while syncAgain
    }

    /// Takes the account's ledger as this Mac's copy, so edits from the phone show up (and the pocket reacts).
    private func adopt(_ next: Ledger) -> Bool {
        let before = ledger.balance
        if next == ledger && loadError == nil { return true }
        guard persist(next) else { return false }
        if let r = receipt {
            switch r.target {
            case .editEntry(let id): if let mapped = journal.ids[id] { receipt = EntryReceipt(text: r.text, target: .editEntry(mapped)) }
            case .editRule(let id): if let mapped = journal.ids[id] { receipt = EntryReceipt(text: r.text, target: .editRule(mapped)) }
            default: break
            }
        }
        ledger = next
        if next.balance != before {
            announce(diff: next.balance - before, before: before, category: nil, deleted: false)
        }
        scheduleReminders()
        return true
    }

    private func flush(_ key: String) async throws {
        while let op = journal.outbox.first(where: { !$0.needsReview }) {
            var args = (try JSONSerialization.jsonObject(with: op.arguments)) as? [String: Any] ?? [:]
            // Something added on this Mac moments ago is known to the account by the account's id.
            if let id = (args["p_id"] as? String).flatMap(UUID.init(uuidString:)), let mapped = journal.ids[id] {
                args["p_id"] = mapped.uuidString
            }
            do {
                let data = try await client.rpc(op.function, args, key: key)
                guard key == accountKey else { return }
                if let local = op.localID,
                   let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                   let remote = (obj["id"] as? String).flatMap(UUID.init(uuidString:)) {
                    journal.ids[local] = remote
                }
                journal.outbox.removeAll { $0.id == op.id }
                saveJournal()
            } catch let e as URLError {
                if !AccountClient.safeToRetry.contains(e.code), let i = journal.outbox.firstIndex(where: { $0.id == op.id }) {
                    journal.outbox[i].needsReview = true
                    journal.outbox[i].message = "It may have reached your account. Check before retrying."
                    saveJournal()
                }
                throw e
            } catch let e as APIError where !e.badKey {
                if let i = journal.outbox.firstIndex(where: { $0.id == op.id }) {
                    journal.outbox[i].needsReview = true
                    journal.outbox[i].message = e.message
                    saveJournal()
                }
            }
        }
    }

    /// Joins an account with a 6-digit code made on a device that's already connected.
    func connect(code: String, server target: Server? = nil) async throws {
        let target = target ?? server
        let data = try await AccountClient(session: session, server: target)
            .rpc("pocket_pair_finish", ["p_code": code, "p_name": AccountConfig.deviceName], key: nil)
        let result = (try JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard let token = result?["token"] as? String else {
            switch result?["error"] as? String {
            case "expired": throw APIError(badKey: false, message: "That code expired or was already used. Make a new one.")
            case "too_many": throw APIError(badKey: false, message: "Too many tries. Make a new code on the other device.")
            default: throw APIError(badKey: false, message: "That code didn't match. Check it and try again.")
            }
        }
        try await connect(key: token, server: target)
    }

    /// Uses an access key (from pairing, or the Pocket Sync app on this Mac). Checks it before switching.
    func connect(key raw: String, server target: Server? = nil) async throws {
        let target = target ?? server
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let data: Data
        do { data = try await AccountClient(session: session, server: target).rpc("pocket_state", ["p_today": Day.today.iso, "p_days": 1], key: key) }
        catch let e as APIError where e.badKey { throw APIError(badKey: true, message: "That access was removed. Make a pairing code instead.") }
        catch is URLError { throw APIError(badKey: false, message: "Couldn't reach your account. Check your connection.") }
        let state = try Store.decoder().decode(ServerState.self, from: data)
        subscriptionSyncAvailable = state.subscription_tracking == true
        let copy = state.ledger(currency: ledger.currency)
        do {
            try Store.encoder().encode(copy).write(to: accountURL, options: .atomic)
        } catch {
            throw APIError(badKey: false, message: "Couldn't save the copy on this Mac: \(error.localizedDescription)")
        }
        keyStore.save(key)
        use(target)
        accountKey = key
        journal = SyncJournal(lastSync: Date())
        saveJournal()
        receipt = nil
        ledger = copy
        loadError = nil
        saveError = nil
        syncState = .ok(Date())
        onboarded = true
        scheduleReminders()
    }

    private func use(_ target: Server) {
        server = target
        defaults.set(try? JSONEncoder().encode(target), forKey: "accountServer")
    }

    /// Claims a brand-new server (your own Supabase project with Pocket's SQL loaded) and moves what's on
    /// this Mac into it. The upload goes through the outbox, so it survives a dropped connection.
    func setUp(_ target: Server) async throws {
        guard !connected else { return }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw APIError(badKey: false, message: "Couldn't make a secure key.")
        }
        let key = bytes.map { String(format: "%02x", $0) }.joined()
        let data: Data
        do { data = try await AccountClient(session: session, server: target).rpc("pocket_setup", ["p_key": key], key: nil) }
        catch let e as APIError where e.message.hasPrefix("HTTP 404") || e.message.contains("pocket_setup") {
            throw APIError(badKey: false, message: "Pocket's SQL isn't loaded on that server yet. Follow the self-hosting guide, then try again.")
        }
        catch is URLError { throw APIError(badKey: false, message: "Couldn't reach that server. Check the address and your connection.") }
        let result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard result?["ok"] as? Bool == true else {
            throw APIError(badKey: false, message: result?["error"] as? String == "already_set_up"
                ? "That server already has a Pocket. Join it with a pairing code from one of its devices."
                : "Couldn't set up that server.")
        }
        let local = ledger
        keyStore.save(key)
        use(target)
        accountKey = key
        journal = SyncJournal()
        guard persist(local) else { throw APIError(badKey: false, message: saveError ?? "Couldn't save on this Mac.") }
        // Oldest first, so the account lists them in the same order.
        for e in local.entries.sorted(by: { ($0.day, $0.created) < ($1.day, $1.created) }) where e.cents != 0 {
            send("pocket_add", ["p_amount": dollars(e.cents), "p_label": String(e.label.prefix(120)), "p_on": e.day.iso,
                                "p_category": e.category ?? NSNull()], label: e.label, localID: e.id, start: false)
        }
        for r in local.rules where !r.finished {
            var args: [String: Any] = ["p_amount": dollars(r.cents), "p_label": String(r.label.prefix(120)), "p_cadence": r.cadence.rawValue,
                                       "p_start": r.next.iso, "p_today": today.iso, "p_category": r.category ?? NSNull(), "p_auto": r.auto]
            if let left = r.remaining { args["p_times"] = left }
            if let subscription = r.subscription { args["p_subscription"] = subscription }
            send("pocket_recurring_add", args, label: r.label, localID: r.id, start: false)
            if !r.active {
                send("pocket_recurring_set_active", ["p_id": r.id.uuidString, "p_active": false, "p_today": today.iso], label: r.label, start: false)
            }
        }
        for p in local.presets {
            send("pocket_preset_save", ["p_label": p.label, "p_sign": p.sign, "p_amount": p.cents.map(dollars) ?? NSNull(),
                                        "p_category": p.category ?? ""], label: p.label, localID: p.id, start: false)
        }
        syncState = .syncing
        onboarded = true
        await syncNow()
    }

    /// Stops syncing. This Mac keeps everything as its local ledger; changes not yet sent are dropped.
    @discardableResult
    func disconnect() -> Bool {
        guard connected else { return true }
        guard loadError == nil else { saveError = loadError; return false }
        let copy = ledger
        if FileManager.default.fileExists(atPath: localURL.path) {
            let backups = localURL.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
            try? FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: localURL, to: backups.appendingPathComponent("ledger-before-disconnect-\(Int(Date().timeIntervalSince1970)).json"))
        }
        // Keep account access and its outbox until the local copy is safely on disk.
        do {
            try Store.encoder().encode(copy).write(to: localURL, options: .atomic)
        } catch {
            saveError = "Couldn't keep a local copy: \(error.localizedDescription)"
            return false
        }
        keyStore.save(nil)
        accountKey = nil
        journal = SyncJournal()
        try? FileManager.default.removeItem(at: journalURL)
        syncState = .offline
        receipt = nil
        loadError = nil
        saveError = nil
        ledger = copy
        scheduleReminders()
        return true
    }

    func retry(_ id: UUID) {
        guard let i = journal.outbox.firstIndex(where: { $0.id == id }) else { return }
        journal.outbox[i].needsReview = false
        journal.outbox[i].message = nil
        saveJournal()
        Task { await syncNow() }
    }

    /// Drops a change that didn't sync. The account's version comes back on the next sync.
    func discard(_ id: UUID) {
        journal.outbox.removeAll { $0.id == id }
        saveJournal()
        Task { await syncNow() }
    }

    func pairStart() async throws -> (code: String, expires: Date) {
        let data = try await client.rpc("pocket_pair_start", key: accountKey)
        let obj = (try JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard let code = obj?["code"] as? String, code.count == 6, code.allSatisfy(\.isNumber) else {
            throw APIError(badKey: false, message: "Couldn't make a code.")
        }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expires = (obj?["expires_at"] as? String).flatMap { f.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) }
        return (code, expires ?? Date().addingTimeInterval(600))
    }

    func devices() async throws -> DevicesResponse {
        try JSONDecoder().decode(DevicesResponse.self, from: await client.rpc("pocket_devices", key: accountKey))
    }

    func removeDevice(_ device: Device) async throws {
        _ = try await client.rpc("pocket_device_remove", ["p_id": device.id], key: accountKey)
        if device.this { disconnect() }
    }

    // MARK: reminders

    private func requestNotificationPermission() {
        guard reminderClient != nil && (reminders || subscriptionReminders) else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                if try await !self.notificationPermission(), self.reminders || self.subscriptionReminders {
                    self.reminderMessage = "Allow Pocket in System Settings → Notifications to receive reminders."
                }
            } catch {
                self.reminderMessage = "Couldn't enable notifications: \(error.localizedDescription)"
            }
            self.scheduleReminders()
        }
    }

    private func notificationPermission() async throws -> Bool {
        guard let client = reminderClient else { return false }
        let status = await client.authorization()
        if status == .notDetermined { return try await client.requestAuthorization() }
        return status == .authorized || status == .provisional
    }

    func sendTestReminder() async {
        guard let client = reminderClient else {
            reminderMessage = "Notifications are disabled in this demo."
            return
        }
        guard reminders else { reminderMessage = "Turn reminders on first."; return }
        guard !sendingTestReminder else { return }
        sendingTestReminder = true
        reminderMessage = nil
        defer { sendingTestReminder = false }
        do {
            guard try await notificationPermission() else {
                reminderMessage = "Allow Pocket in System Settings → Notifications, then try again."
                return
            }
            guard reminders else { return }
            let content = UNMutableNotificationContent()
            if let rule = ledger.liveRules.first(where: { !$0.auto }) {
                content.title = rule.cents > 0 ? "Did \(rule.label) pay?" : "Was \(rule.label) paid?"
            } else {
                content.title = "Payment reminder"
            }
            content.body = "Open Pocket to log it, with the real amount if it changed."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            try await client.add(UNNotificationRequest(identifier: PaymentReminders.testIdentifier,
                                                      content: content, trigger: trigger))
            reminderMessage = "Test reminder scheduled for five seconds from now."
            scheduleReminders()
        } catch {
            reminderMessage = "Couldn't send the test reminder: \(error.localizedDescription)"
        }
    }

    /// Serialize refreshes so an edit, wake or permission callback cannot restore an obsolete reminder.
    private func scheduleReminders() {
        guard let client = reminderClient else { return }
        reminderRefreshNeeded = true
        guard reminderTask == nil else { return }
        reminderTask = Task { [weak self] in
            guard let self else { return }
            while self.reminderRefreshNeeded {
                self.reminderRefreshNeeded = false
                let now = self.reminderNow()
                let plans = PaymentReminders.plans(for: self.ledger.liveRules, now: now,
                                                  payments: self.reminders, subscriptions: self.subscriptionReminders)
                let enabled = (self.reminders || self.subscriptionReminders) && self.loadError == nil
                let status = await client.authorization()
                let pending = await client.pending()
                if self.reminderRefreshNeeded { continue }
                let allowed = status == .authorized || status == .provisional
                let ids = Set(plans.map(\.identifier))
                let canceled = pending.filter {
                    ($0.identifier.hasPrefix("pocket.") && (!enabled || !allowed || !ids.contains($0.identifier)))
                        || ($0.identifier == PaymentReminders.testIdentifier && (!enabled || !allowed))
                }.map(\.identifier)
                client.remove(canceled)
                let today = Day(now).iso
                var requested = Set((self.defaults.stringArray(forKey: "reminderRequestedOccurrences") ?? [])
                    .filter { String($0.suffix(10)) >= today })
                requested.subtract(canceled)
                self.defaults.set(requested.sorted(), forKey: "reminderRequestedOccurrences")
                guard enabled && allowed else {
                    if enabled {
                        self.reminderMessage = "Allow Pocket in System Settings → Notifications to receive reminders."
                    }
                    continue
                }
                var failed = false
                for plan in plans {
                    if self.reminderRefreshNeeded { break }
                    let existing = pending.first { $0.identifier == plan.identifier }
                    let trigger: UNNotificationTrigger
                    if plan.date <= now {
                        if !plan.catchUp { continue }
                        // Preserve a queued due-day reminder; after delivery/dismissal, don't post it again.
                        if existing != nil || requested.contains(plan.identifier) { continue }
                        trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                    } else {
                        let calendarTrigger = PaymentReminders.calendarTrigger(for: plan)
                        if let existing,
                           existing.content.title == plan.title, existing.content.body == plan.body,
                           let previous = existing.trigger as? UNCalendarNotificationTrigger,
                           previous.dateComponents == calendarTrigger.dateComponents { continue }
                        trigger = calendarTrigger
                    }
                    do {
                        try await client.add(UNNotificationRequest(identifier: plan.identifier,
                                                                  content: plan.content, trigger: trigger))
                        requested.insert(plan.identifier)
                        self.defaults.set(requested.sorted(), forKey: "reminderRequestedOccurrences")
                    } catch {
                        failed = true
                        self.reminderMessage = "Couldn't schedule a payment reminder: \(error.localizedDescription)"
                    }
                }
                if !failed && !self.reminderRefreshNeeded,
                   let message = self.reminderMessage,
                   message.hasPrefix("Couldn't schedule a payment reminder") || message.hasPrefix("Allow Pocket") {
                    self.reminderMessage = nil
                }
            }
            self.reminderTask = nil
        }
    }

    /// Wait for the same scheduler used by the app (also used for regression tests).
    func refreshReminders() async {
        scheduleReminders()
        await reminderTask?.value
    }
}
