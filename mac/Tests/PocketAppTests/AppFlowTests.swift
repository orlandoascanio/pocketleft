import AppKit
import PocketCore
import SwiftUI
import XCTest
@testable import Pocket

@MainActor
final class AppFlowTests: XCTestCase {
    private func isolatedStore() throws -> Store {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pocket-flow-\(UUID())")
        let suite = "pocket-tests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(false, forKey: "reminders")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        return Store(directory: directory, defaults: defaults, servicesEnabled: false)
    }

    private func blockWrites(_ store: Store) throws -> URL {
        let backup = store.fileURL.appendingPathExtension("saved")
        try FileManager.default.moveItem(at: store.fileURL, to: backup)
        try FileManager.default.createDirectory(at: store.fileURL, withIntermediateDirectories: false)
        return backup
    }

    private func unblockWrites(_ store: Store, backup: URL) throws {
        try FileManager.default.removeItem(at: store.fileURL)
        try FileManager.default.moveItem(at: backup, to: store.fileURL)
    }

    func testStartingBalanceCannotBeAddedTwice() throws {
        let store = try isolatedStore()
        XCTAssertFalse(store.onboarded)
        XCTAssertTrue(store.start(currency: "EUR", cents: -12_500, openAtLogin: false))
        let saved = try Data(contentsOf: store.fileURL)
        XCTAssertTrue(store.onboarded)
        XCTAssertFalse(store.hasRecordedEntries, "A starting balance isn't a first expense")
        XCTAssertFalse(store.start(currency: "USD", cents: 50_000, openAtLogin: false))
        XCTAssertEqual(store.balance, -12_500)
        XCTAssertEqual(store.ledger.currency, "EUR")
        XCTAssertEqual(try Data(contentsOf: store.fileURL), saved)

        let reopened = Store(directory: store.fileURL.deletingLastPathComponent(),
                             defaults: UserDefaults(suiteName: "pocket-fresh-\(UUID())"), servicesEnabled: false)
        XCTAssertTrue(reopened.onboarded, "Saved money must be recognized even if the welcome preference is missing")
        XCTAssertFalse(reopened.start(currency: "USD", cents: 50_000, openAtLogin: false))
        XCTAssertEqual(reopened.balance, -12_500)
    }

    func testFailedSetupCanRetryWithoutReportingAReadyBalance() throws {
        let store = try isolatedStore()
        try FileManager.default.createDirectory(at: store.fileURL, withIntermediateDirectories: false)
        XCTAssertFalse(store.start(currency: "EUR", cents: 12_500, openAtLogin: false))
        XCTAssertFalse(store.onboarded)
        XCTAssertEqual(store.menuTitle, "Pocket")
        XCTAssertEqual(store.balance, 0)
        XCTAssertNotNil(store.saveError)
        try FileManager.default.removeItem(at: store.fileURL)
        XCTAssertTrue(store.start(currency: "EUR", cents: 12_500, openAtLogin: false))
        XCTAssertNil(store.saveError)
        XCTAssertEqual(store.balance, 12_500)
        XCTAssertEqual(store.ledger.entries.count, 1)
    }

    func testZeroSetupStaysReadyAndFirstExpenseUpdatesBalance() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 0, openAtLogin: false))
        XCTAssertTrue(store.onboarded)
        XCTAssertFalse(store.hasRecordedEntries)
        XCTAssertTrue(store.addRule(Rule(cents: -500, label: "Tomorrow", cadence: .monthly,
                                         anchor: Day.today.adding(days: 1), auto: false)))
        XCTAssertFalse(store.hasRecordedEntries, "A planned payment isn't money recorded yet")
        let state = EditorState(); state.store = store
        state.amount = "6.50"; state.label = "Coffee"
        XCTAssertTrue(state.save())
        XCTAssertEqual(store.balance, -650)
        XCTAssertTrue(store.hasRecordedEntries)
        XCTAssertNotNil(store.receipt)
        XCTAssertFalse(store.start(currency: "USD", cents: 100, openAtLogin: false))
    }

    func testFailedEntrySaveKeepsDraftAndRetryAddsExactlyOnce() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 10_000, openAtLogin: false))
        let state = EditorState()
        state.store = store
        state.amount = "6.50"
        state.label = "Coffee"
        state.savePreset = true
        let backup = try blockWrites(store)
        XCTAssertFalse(state.save())
        XCTAssertEqual(store.balance, 10_000)
        XCTAssertEqual(store.ledger.entries.count, 1)
        XCTAssertTrue(store.ledger.presets.isEmpty)
        XCTAssertEqual(state.amount, "6.50")
        XCTAssertEqual(state.label, "Coffee")
        XCTAssertEqual(state.saved, 0)
        XCTAssertNil(store.receipt)
        XCTAssertNotNil(store.saveError)
        try unblockWrites(store, backup: backup)
        XCTAssertTrue(state.save())
        XCTAssertEqual(store.balance, 9_350)
        XCTAssertEqual(store.ledger.entries.count, 2)
        XCTAssertEqual(store.ledger.presets.count, 1)
        XCTAssertNil(store.saveError)
        XCTAssertEqual(state.saved, 1)
        XCTAssertNotNil(store.receipt)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let disk = try decoder.decode(Ledger.self, from: Data(contentsOf: store.fileURL))
        XCTAssertEqual(disk.balance, store.balance)
        XCTAssertEqual(disk.presets.count, 1)
    }

    func testFailedSettlementDoesNotAdvanceAndStaleConfirmationCannotPostTwice() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 10_000, openAtLogin: false))
        XCTAssertTrue(store.addRule(Rule(cents: 20_000, label: "Client", cadence: .monthly, anchor: .today, auto: false)))
        let payment = try XCTUnwrap(store.waiting.first)
        let backup = try blockWrites(store)
        XCTAssertFalse(store.settle(payment, cents: 18_000, on: .today))
        XCTAssertEqual(store.balance, 10_000)
        XCTAssertEqual(store.waiting.count, 1)
        try unblockWrites(store, backup: backup)
        XCTAssertTrue(store.settle(payment, cents: 18_000, on: .today))
        XCTAssertEqual(store.balance, 28_000)
        XCTAssertFalse(store.settle(payment, cents: 18_000, on: .today))
        XCTAssertEqual(store.balance, 28_000)
        XCTAssertEqual(store.ledger.rules.first?.posted, 1)
    }

    func testFailedSkipRetainsPaymentAndRetryAdvancesOnlyOnce() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 10_000, openAtLogin: false))
        XCTAssertTrue(store.addRule(Rule(cents: 20_000, label: "Client", cadence: .monthly, anchor: .today, auto: false)))
        let payment = try XCTUnwrap(store.waiting.first)
        let backup = try blockWrites(store)
        XCTAssertFalse(store.skip(payment))
        XCTAssertEqual(store.ledger.rules.first?.posted, 0)
        XCTAssertEqual(store.waiting.count, 1)
        XCTAssertEqual(store.balance, 10_000)
        try unblockWrites(store, backup: backup)
        XCTAssertTrue(store.skip(payment))
        XCTAssertEqual(store.ledger.rules.first?.posted, 1)
        XCTAssertFalse(store.skip(payment))
        XCTAssertEqual(store.ledger.rules.first?.posted, 1)
        XCTAssertEqual(store.balance, 10_000)
    }

    func testAutomaticDuePaymentReloadDoesNotPostTwice() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 10_000, openAtLogin: false))
        XCTAssertTrue(store.addRule(Rule(cents: -500, label: "Bill", cadence: .monthly, anchor: .today, auto: false)))
        let file = try Data(contentsOf: store.fileURL)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var ledger = try decoder.decode(Ledger.self, from: file)
        ledger.rules[0].auto = true
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(ledger).write(to: store.fileURL)
        // Reload reads the automatic rule and posts it once; another tick must not duplicate it.
        let reloaded = Store(directory: store.fileURL.deletingLastPathComponent(), defaults: UserDefaults(suiteName: "pocket-reload-\(UUID())"), servicesEnabled: false)
        XCTAssertEqual(reloaded.balance, 9_500)
        reloaded.tick()
        XCTAssertEqual(reloaded.balance, 9_500)
        XCTAssertEqual(reloaded.ledger.rules.first?.posted, 1)
    }

    func testDraftHandoffPreservesInputAndRevealsOptions() {
        let state = EditorState()
        state.load(EntryDraft(spent: false, amount: "123.45", label: "Paycheck", category: "pay"))
        XCTAssertFalse(state.spent)
        XCTAssertEqual(state.amount, "123.45")
        XCTAssertEqual(state.label, "Paycheck")
        XCTAssertEqual(state.category, "pay")
        XCTAssertTrue(state.showDetails)
    }

    func testInvalidEntryDoesNotReportSuccessOrChangeBalance() throws {
        let store = try isolatedStore()
        let state = EditorState(); state.store = store
        state.amount = "abc"; state.label = "Coffee"
        XCTAssertFalse(state.save())
        XCTAssertEqual(store.balance, 0)
        XCTAssertEqual(state.saved, 0)
        XCTAssertTrue(store.ledger.entries.isEmpty)
        XCTAssertNotNil(state.error)
    }

    func testNativeRenderPreviews() throws {
        guard let output = ProcessInfo.processInfo.environment["POCKET_SNAPSHOT_DIR"] else { throw XCTSkip("Set POCKET_SNAPSHOT_DIR to render native previews") }
        _ = NSApplication.shared
        try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 33_703, openAtLogin: false))
        _ = store.addEntry(cents: -650, label: "Coffee", day: .today, category: "food")
        _ = store.addEntry(cents: -1599, label: "A very long purchase description that should still fit in the menu", day: .today, category: "games")
        store.savePreset(Preset(label: "Coffee", cents: 650, sign: -1, category: "food"))
        store.savePreset(Preset(label: "Gift", cents: nil, sign: 1, category: "gift"))
        _ = store.addEntry(cents: 2_500, label: "Refund", day: .today, category: "refund")
        _ = store.addRule(Rule(cents: -2_000, label: "AI subscription", cadence: .monthly, anchor: Day.today.adding(days: 5), category: "subscriptions"))
        for i in 1...12 {
            _ = store.addRule(Rule(cents: i * 10000, label: "Client \(i) · monthly work", cadence: .monthly, anchor: .today, auto: false))
        }
        try store.export(to: URL(fileURLWithPath: output + "/demo-ledger.json"))
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            NSApp.appearance = NSAppearance(named: appearance)
            try capture(MainWindow().environmentObject(store), size: NSSize(width: 1000, height: 780), path: output + "/overview-\(name).png")
            try capture(MainWindow().environmentObject(store), size: NSSize(width: 780, height: 560), path: output + "/minimum-\(name).png")
            try capture(MenuPanel().environmentObject(store), size: NSSize(width: 380, height: 640), path: output + "/menu-\(name).png")
            try capture(PlanView(onEdit: { _ in }).environmentObject(store), size: NSSize(width: 820, height: 900), path: output + "/plan-\(name).png")
            try capture(PlanView(onEdit: { _ in }).environmentObject(store), size: NSSize(width: 580, height: 560), path: output + "/plan-minimum-\(name).png")
            try capture(InsightsView(onEdit: { _ in }).environmentObject(store), size: NSSize(width: 820, height: 640), path: output + "/insights-\(name).png")
            try capture(SettingsView().environmentObject(store), size: NSSize(width: 820, height: 760), path: output + "/settings-\(name).png")
            try capture(SettingsView().environmentObject(store), size: NSSize(width: 580, height: 560), path: output + "/settings-minimum-\(name).png")
            try capture(EditSheet(target: EditTarget(kind: .new(nil))).environmentObject(store), size: NSSize(width: 460, height: 460), path: output + "/new-entry-\(name).png")
        }
        NSApp.appearance = NSAppearance(named: .aqua)
        try capture(PlanView(onEdit: { _ in }).environmentObject(store), size: NSSize(width: 820, height: 2_300), path: output + "/plan-full.png")
        try capture(SettingsView().environmentObject(store), size: NSSize(width: 820, height: 1_500), path: output + "/settings-full.png")
        let state = EditorState(); state.store = store; state.showDetails = true
        state.label = "Rent"; state.amount = "850"; state.frequency = .monthly
        try capture(EntryEditor(state: state).frame(width: 460).environmentObject(store), size: NSSize(width: 460, height: 600), path: output + "/entry-options.png")
        let payment = try XCTUnwrap(store.waiting.first)
        try capture(WaitingCard(occurrence: payment, initiallyExpanded: true).environmentObject(store), size: NSSize(width: 560, height: 130), path: output + "/waiting.png")
        try capture(WaitingCard(occurrence: payment).environmentObject(store), size: NSSize(width: 560, height: 80), path: output + "/waiting-card.png")
        let owed = EditorState(); owed.store = store; owed.showDetails = true
        owed.spent = false; owed.label = "Sam owes me"; owed.amount = "50"; owed.awaiting = true
        try capture(EntryEditor(state: owed).frame(width: 460).environmentObject(store), size: NSSize(width: 460, height: 560), path: output + "/entry-waiting.png")
        let empty = try isolatedStore()
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            NSApp.appearance = NSAppearance(named: appearance)
            try capture(Onboarding().environmentObject(empty), size: NSSize(width: 470, height: 640), path: output + "/onboarding-start-\(name).png")
        }
        XCTAssertTrue(empty.start(currency: "USD", cents: 0, openAtLogin: false))
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            NSApp.appearance = NSAppearance(named: appearance)
            try capture(Onboarding().environmentObject(empty), size: NSSize(width: 470, height: 640), path: output + "/onboarding-ready-\(name).png")
            try capture(MainWindow().environmentObject(empty), size: NSSize(width: 780, height: 560), path: output + "/first-entry-\(name).png")
            try capture(MenuPanel().environmentObject(empty), size: NSSize(width: 340, height: 460), path: output + "/first-entry-menu-\(name).png")
        }
        NSApp.appearance = NSAppearance(named: .aqua)
        try capture(MainWindow().environmentObject(empty), size: NSSize(width: 780, height: 560), path: output + "/minimum-zero.png")
        try capture(MenuPanel().environmentObject(empty), size: NSSize(width: 380, height: 420), path: output + "/menu-empty.png")
        try capture(Onboarding().environmentObject(empty), size: NSSize(width: 470, height: 680), path: output + "/onboarding.png")
        try capture(WaitingCard(occurrence: payment, initiallyExpanded: true,
                                initialError: "Couldn't skip this payment. Try again.").environmentObject(store),
                    size: NSSize(width: 380, height: 200), path: output + "/waiting-skip-failure.png")
        _ = store.addEntry(cents: -1_450, label: "Lunch", day: .today, category: "food")
        try capture(MenuPanel().environmentObject(store), size: NSSize(width: 380, height: 640), path: output + "/menu-receipt.png")
        let blocked = try blockWrites(store)
        _ = store.addEntry(cents: -100, label: "Failed", day: .today, category: nil)
        try capture(MenuPanel().environmentObject(store), size: NSSize(width: 380, height: 640), path: output + "/menu-save-failure.png")
        try unblockWrites(store, backup: blocked)
        _ = store.addEntry(cents: -store.balance - 125_000_000, label: "Large negative balance", day: .today, category: nil)
        try capture(MainWindow().environmentObject(store), size: NSSize(width: 780, height: 560), path: output + "/minimum-large-negative.png")
        try capture(MenuPanel().environmentObject(store), size: NSSize(width: 380, height: 640), path: output + "/menu-large-negative.png")
    }

    func testEditingStartingBalanceKeepsItOutOfIncomeAndAllowsZero() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 10000, openAtLogin: false))
        let state = EditorState(); state.store = store
        state.load(try XCTUnwrap(store.ledger.entries.first))
        state.amount = "125"
        XCTAssertTrue(state.save())
        XCTAssertEqual(store.balance, 12500)
        XCTAssertEqual(store.ledger.summary(nil).income, 0)
        XCTAssertEqual(store.ledger.entries.first?.category, Categories.start)
        state.load(try XCTUnwrap(store.ledger.entries.first))
        state.amount = "0"
        XCTAssertTrue(state.save())
        XCTAssertEqual(store.balance, 0)
        XCTAssertEqual(store.ledger.summary(nil).income, 0)
    }

    func testPresetEditingRejectsInvalidInputAndRetainsFailedDraft() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 10000, openAtLogin: false))
        let preset = Preset(label: "Coffee", cents: 650, sign: -1, category: "food")
        XCTAssertTrue(store.savePreset(preset))
        let state = PresetEditorState(preset)
        state.amount = "oops"
        XCTAssertFalse(state.save(in: store))
        XCTAssertEqual(store.ledger.presets.first?.cents, 650)
        state.label = "Lunch"; state.amount = "8.50"; state.category = "food"
        let backup = try blockWrites(store)
        XCTAssertFalse(state.save(in: store))
        XCTAssertEqual(state.amount, "8.50")
        XCTAssertEqual(store.ledger.presets.first?.label, "Coffee")
        try unblockWrites(store, backup: backup)
        XCTAssertTrue(state.save(in: store))
        XCTAssertFalse(state.hasChanges)
        XCTAssertEqual(store.ledger.presets.first?.cents, 850)
        XCTAssertEqual(store.ledger.presets.first?.label, "Lunch")
        state.amount = ""
        XCTAssertTrue(state.save(in: store))
        XCTAssertNil(store.ledger.presets.first?.cents)
    }

    func testUnreadableLedgerCannotBeOverwrittenAndCanRecover() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 10000, openAtLogin: false))
        let saved = try Data(contentsOf: store.fileURL)
        let damaged = Data("damaged JSON".utf8)
        try damaged.write(to: store.fileURL)
        let reloaded = Store(directory: store.fileURL.deletingLastPathComponent(), servicesEnabled: false)
        XCTAssertNotNil(reloaded.loadError)
        XCTAssertEqual(reloaded.menuTitle, "Pocket ⚠︎")
        XCTAssertNil(reloaded.addEntry(cents: -100, label: "Coffee", day: .today, category: nil))
        XCTAssertEqual(try Data(contentsOf: store.fileURL), damaged)
        try saved.write(to: store.fileURL)
        reloaded.retryLoadingData()
        XCTAssertNil(reloaded.loadError)
        XCTAssertEqual(reloaded.balance, 10000)
    }

    func testInvalidImportKeepsExistingDiskAndBalance() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 10000, openAtLogin: false))
        let before = try Data(contentsOf: store.fileURL)
        let entry = try XCTUnwrap(store.ledger.entries.first)
        let invalid = Ledger(currency: "USD", entries: [entry, entry])
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let url = store.fileURL.deletingLastPathComponent().appendingPathComponent("invalid.json")
        try encoder.encode(invalid).write(to: url)
        XCTAssertThrowsError(try store.importFile(url))
        XCTAssertEqual(store.balance, 10000)
        XCTAssertEqual(try Data(contentsOf: store.fileURL), before)
    }

    func testStalePaymentActionsCannotSettleOrSkipAPausedRule() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 10000, openAtLogin: false))
        XCTAssertTrue(store.addRule(Rule(cents: 20000, label: "Client", cadence: .monthly, anchor: .today, auto: false)))
        let payment = try XCTUnwrap(store.waiting.first)
        XCTAssertTrue(store.setActive(payment.ruleID, false))
        XCTAssertFalse(store.settle(payment, cents: 20000, on: .today))
        XCTAssertFalse(store.skip(payment))
        XCTAssertEqual(store.balance, 10000)
        XCTAssertEqual(store.ledger.rules.first?.posted, 0)
    }

    func testSignedAmountsChooseTheSameDirectionInEveryEditor() throws {
        let store = try isolatedStore()
        XCTAssertTrue(store.start(currency: "USD", cents: 10000, openAtLogin: false))
        let state = EditorState(); state.store = store
        state.amount = "+20.50"; state.label = "Gift"
        XCTAssertFalse(state.spent)
        XCTAssertEqual(state.amount, "20.50")
        XCTAssertTrue(state.save())
        XCTAssertEqual(store.balance, 12050)
        state.amount = "-6.50"; state.label = "Coffee"
        XCTAssertTrue(state.spent)
        XCTAssertTrue(state.save())
        XCTAssertEqual(store.balance, 11400)
        state.amount = "--12"; state.label = "Invalid"
        XCTAssertFalse(state.save())
        XCTAssertEqual(store.balance, 11400)
    }

    func testSavingPresetNamePreservesAnAmountUpdatedElsewhere() throws {
        let store = try isolatedStore()
        let preset = Preset(label: "Coffee", cents: 650, sign: -1, category: "food")
        XCTAssertTrue(store.savePreset(preset))
        let state = PresetEditorState(preset)
        state.label = "Lunch"
        var newer = preset; newer.cents = 850
        XCTAssertTrue(store.savePreset(newer))
        XCTAssertTrue(state.save(in: store))
        XCTAssertEqual(store.ledger.presets.first?.label, "Lunch")
        XCTAssertEqual(store.ledger.presets.first?.cents, 850)
    }

    private func capture<V: View>(_ view: V, size: NSSize, path: String) throws {
        let dark = NSApp.appearance?.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let host = NSHostingView(rootView: view
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(Palette.bg)
            .environment(\.colorScheme, dark ? .dark : .light)
            .transaction { $0.disablesAnimations = true })
        host.sizingOptions = []
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = host.appearance
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.bounds.size, size)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: path))
        window.orderOut(nil)
    }
}
