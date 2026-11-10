import AppKit
import PocketCore
import SwiftUI
@preconcurrency import UserNotifications

extension Notification.Name {
    static let pocketReminderOpened = Notification.Name("PocketReminderOpened")
}

final class PocketNotificationDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
           id.hasPrefix("pocket.") || id == PaymentReminders.testIdentifier {
            let subscriptions = response.notification.request.content.userInfo["subscriptions"] as? Bool ?? false
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .pocketReminderOpened, object: nil,
                                                userInfo: ["subscriptions": subscriptions])
            }
        }
        completionHandler()
    }
}

@main
struct PocketApp: App {
    @NSApplicationDelegateAdaptor(PocketNotificationDelegate.self) private var notificationDelegate
    @StateObject private var store = Store()

    var body: some Scene {
        MenuBarExtra {
            MenuPanel().environmentObject(store)
        } label: {
            MenuLabel().environmentObject(store)
        }
        .menuBarExtraStyle(.window)

        Window("Pocket", id: "main") {
            MainWindow()
                .environmentObject(store)
                .frame(minWidth: 780, minHeight: 560)
        }
        .defaultSize(width: 1000, height: 780)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Pocket") { AboutPanel.show() }
                Button("Check for Updates…") { UpdateChecker.shared.checkAndReport() }
                Button("Share Pocket…") { SharePocket.show() }
            }
            QuickAddCommands(store: store)
        }

        Window("Welcome to Pocket", id: "welcome") {
            Onboarding().environmentObject(store)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

/// The Quick Add menu: the buttons with ⌘1 to ⌘9 on every page of the window, not only next to the row.
struct QuickAddCommands: Commands {
    @ObservedObject var store: Store

    var body: some Commands {
        CommandMenu("Quick Add") {
            let presets = store.ledger.presets
            if presets.isEmpty {
                Text("No quick-add buttons yet")
            }
            ForEach(Array(presets.enumerated()), id: \.element.id) { i, p in
                let title = p.cents.map { "\(p.label)  \(store.money.string(p.sign * $0, signed: p.sign > 0))" } ?? "\(p.label)…"
                if i < 9 {
                    Button(title) { store.useQuickAdd(p) }
                        .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: .command)
                } else {
                    Button(title) { store.useQuickAdd(p) }
                }
            }
            .disabled(store.loadError != nil)
            Divider()
            Button("Edit Quick-Add Buttons…") { store.windowRequest = .section(.settings) }
        }
    }
}

/// The menubar shows just the balance.
struct MenuLabel: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(store.menuTitle)
            .monospacedDigit()
            .onReceive(NotificationCenter.default.publisher(for: .pocketReminderOpened)) { notification in
                store.windowRequest = notification.userInfo?["subscriptions"] as? Bool == true ? .section(.subscriptions) : .waiting
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .task {
                try? await Task.sleep(for: .milliseconds(400))
                // POCKET_OPEN / POCKET_SECTION (development only) open a window at launch, for screenshots.
                let env = ProcessInfo.processInfo.environment
                if let s = env["POCKET_SECTION"].flatMap(AppSection.init(rawValue:)) { store.windowRequest = .section(s) }
                if let id = env["POCKET_OPEN"] {
                    openWindow(id: id)
                } else if !store.onboarded {
                    openWindow(id: "welcome")
                } else {
                    return
                }
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}

/// First run: save a real balance, then hand off to a first entry.
struct Onboarding: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step = 0
    @State private var currency = Locale.current.currency?.identifier ?? "USD"
    @State private var amount = ""
    @State private var inTheRed = false
    @State private var connecting = false
    @State private var amountError: String?
    @FocusState private var focused: Bool

    static func currencies(including current: String) -> [String] {
        let common = ["USD", "EUR", "GBP", "CAD", "AUD", "MXN", "COP", "ARS", "BRL", "CLP", "PEN", "JPY", "CHF", "INR"]
        return common.contains(current) ? common : [current] + common
    }

    private var face: Face {
        if step == 1 { return .joy }
        if amount.isEmpty { return focused ? .happy : .sleep }
        return inTheRed ? .worried : .hope
    }

    var body: some View {
        VStack(spacing: 18) {
            PocketStage(width: 150, fixedFace: face)
                .padding(.top, 12)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: face)
            if step == 0 { first; SaveFailureView() } else { done }
        }
        .padding(36)
        .frame(width: 470)
        .background(Palette.bg)
        .tint(Palette.accent)
        .onAppear {
            // Reopening Welcome must never offer to add a second starting balance.
            step = store.onboarded ? 1 : 0
            focused = step == 0
        }
        .sheet(isPresented: $connecting) { ConnectSheet() }
        .onChange(of: store.onboarded) { _, on in
            withAnimation(reduceMotion ? nil : .snappy) { step = on ? 1 : 0 }
        }
    }

    private var first: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Know how much is left").font(.display(28, .heavy))
                Text("Set your current balance. Pocket keeps it in your Mac’s menu bar as you record money in and out.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("How much money do you have right now?").font(.headline)
                Picker("Balance direction", selection: $inTheRed) {
                    Text("I have").tag(false)
                    Text("I'm below zero by").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                HStack {
                    TextField("Starting balance", text: $amount, prompt: Text(Money(currency: currency).placeholder))
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .focused($focused)
                        .onSubmit(start)
                        .onChange(of: amount) { _, value in
                            amountError = nil
                            // A pasted signed amount should agree with the direction control.
                            if let sign = value.trimmed.first, sign == "+" || sign == "-" {
                                let rest = String(value.trimmed.dropFirst())
                                if !rest.hasPrefix("+") && !rest.hasPrefix("-") {
                                    inTheRed = sign == "-"
                                    amount = rest
                                }
                            }
                        }
                    Picker("Currency", selection: $currency) {
                        ForEach(Self.currencies(including: currency), id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 90)
                }
                Text("Use the money you have now. Leave this empty to start at zero.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let amountError { Text(amountError).font(.caption).foregroundStyle(Palette.negative) }
            }
            Button(action: start) { Text("Set My Balance").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            Text("Saved on this Mac. An account is optional.")
                .font(.caption).foregroundStyle(.secondary)
            Button(AccountKeyStore.pocketSyncKey() != nil ? "Use your Pocket Sync account instead" : "Already use Pocket on your phone? Connect") {
                connecting = true
            }
            .buttonStyle(.link).font(.callout)
        }
    }

    private var done: some View {
        VStack(spacing: 14) {
            Text("Your balance is ready").font(.display(28, .heavy))
            VStack(spacing: 8) {
                Text("In your menu bar").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Image(systemName: "menubar.rectangle")
                    Text(store.money.string(store.balance))
                        .font(.display(30, .semibold)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .foregroundStyle(store.balance < 0 ? Palette.negative : Color.primary)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line))
            }
            Text(store.hasRecordedEntries
                 ? "Click your balance at the top of your screen whenever you spend or receive money."
                 : "Add an expense to see your balance update. After that, click the balance at the top of your screen for quick entries.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(store.hasRecordedEntries ? "Open Pocket" : "Add My First Expense") {
                store.windowRequest = store.hasRecordedEntries ? .section(.overview) : .firstEntry
                dismissWindow(id: "welcome")
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            Button(store.hasRecordedEntries ? "Done" : "I’ll Add One Later") { dismissWindow(id: "welcome") }
                .buttonStyle(.link)
            Text("You can enable Open at login in Settings.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func start() {
        guard let cents = amount.trimmed.isEmpty ? 0 : Money.parse(amount, allowZero: true) else {
            amountError = "Enter a valid amount, like 125.50, or leave it empty for zero."
            focused = true
            return
        }
        // Login behavior can be chosen later, once a useful balance is visible.
        guard store.start(currency: currency, cents: inTheRed ? -cents : cents, openAtLogin: false) else { return }
        withAnimation(reduceMotion ? nil : .snappy) { step = 1 }
    }
}
