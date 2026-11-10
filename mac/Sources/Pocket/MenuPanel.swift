import AppKit
import PocketCore
import SwiftUI

/// A bounded glance and quick entry; longer lists belong in the main window.
struct MenuPanel: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var quick = EditorState()
    @State private var hovered: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !store.onboarded {
                setup.padding(20)
            } else {
                ScrollView {
                    content.padding(.bottom, 10)
                }
                .frame(height: min(bodyHeight, max(220, min(560, (NSScreen.main?.visibleFrame.height ?? 700) - 100))))
                Divider()
                footer.padding(.horizontal, 10).padding(.vertical, 6)
            }
        }
        .frame(width: 340)
        .background(Palette.bg)
        .tint(Palette.accent)
        .background(shortcutButtons)
        .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0), value: store.receipt?.text)
        .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0), value: quick.error)
        .onAppear { quick.store = store; store.tick(); quick.focusAmount += 1 }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, 16).padding(.top, 14)
            if store.saveError != nil { SaveFailureView().padding(.horizontal, 16).padding(.top, 10) }
            if !store.ledger.presets.isEmpty {
                QuickBar(onAsk: { quick.start(from: $0) }).padding(.horizontal, 10).padding(.top, 12)
            }
            Composer(state: quick, showSaveTitle: !store.hasRecordedEntries, onMore: openOptions).padding(.horizontal, 10).padding(.top, 10)
                .disabled(store.loadError != nil)
            if let error = quick.error {
                Text(error).font(.caption).foregroundStyle(Palette.negative)
                    .padding(.horizontal, 16).padding(.top, 6)
                    .transition(.opacity)
            }
            if store.receipt != nil {
                EntryReceiptView { request($0) }.padding(.horizontal, 16).padding(.top, 8)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
            if store.showSharePrompt { SharePromptView().padding(.horizontal, 10).padding(.top, 8) }
            if !store.waiting.isEmpty { waitingRow.padding(.horizontal, 10).padding(.top, 8) }
            recent.padding(.top, 14)
        }
    }

    /// Rough height of the content, so the panel fits it but never outgrows the screen.
    private var bodyHeight: CGFloat {
        96 + (store.runway == nil ? 0 : 24)
            + (store.ledger.presets.isEmpty ? 0 : 44)
            + 92
            + (store.hasRecordedEntries ? 0 : 36)
            + (quick.error == nil ? 0 : 22)
            + (store.receipt == nil ? 0 : 30)
            + (store.saveError == nil ? 0 : 110)
            + (store.showSharePrompt ? 46 : 0)
            + (store.waiting.isEmpty ? 0 : 44)
            + 40 + CGFloat(max(1, min(3, store.ledger.entries.count))) * 46
    }

    // ⌘O, ⌘, and ⌘Q without spending space on buttons.
    private var shortcutButtons: some View {
        Group {
            Button("Open Pocket") { open("main") }.keyboardShortcut("o")
            Button("Settings") { request(.section(.settings)) }.keyboardShortcut(",")
            Button("New entry") { quick.reset(); quick.focusAmount += 1 }.keyboardShortcut("n")
            Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
        .hidden().accessibilityHidden(true).frame(width: 0, height: 0)
    }

    private var setup: some View {
        VStack(spacing: 12) {
            PocketStage(width: 96, fixedFace: .sleep)
            Text("See how much you have left").font(.headline)
            Text("Start with your current balance.").foregroundStyle(.secondary)
            Button("Set My Balance") { open("welcome") }.buttonStyle(.borderedProminent).controlSize(.large)
        }.frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Money left").font(.subheadline).foregroundStyle(.secondary)
                Text(store.loadError == nil ? store.money.string(store.balance) : "—")
                    .font(.display(34, .semibold)).tracking(-0.6).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .accessibilityLabel("Money left").accessibilityValue(store.loadError == nil ? store.money.string(store.balance) : "Unavailable")
                    .contentTransition(.numericText(value: Double(store.balance)))
                    .foregroundStyle(store.balance < 0 ? Palette.negative : Color.primary)
                    .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0), value: store.balance)
                if store.loadError == nil, let runway = store.runway {
                    Button { request(.section(.plan)) } label: {
                        HStack(spacing: 4) {
                            RunwayLine(runway: runway, range: store.range)
                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .font(.callout)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).padding(.top, 3)
                    .help("Open Plan to see the forecast")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            PocketStage(width: 60)
        }
    }

    private var waitingRow: some View {
        Button { request(.waiting) } label: {
            HStack(spacing: 10) {
                Image(systemName: "clock.badge.exclamationmark").foregroundStyle(.orange).frame(width: 26)
                Text(store.waiting.count == 1 ? "1 payment is waiting for you" : "\(store.waiting.count) payments are waiting for you")
                    .font(.callout)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 6).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hovered == "waiting" ? Color.primary.opacity(0.06) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? "waiting" : nil }
        .help("Confirm or skip them in the Pocket window")
    }

    private var recent: some View {
        let entries = Array(store.ledger.sortedEntries.prefix(3))
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Recent").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if !entries.isEmpty {
                    Button("See All") { request(.history) }
                        .buttonStyle(.plain).font(.subheadline).foregroundStyle(Palette.accent)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 4)
            if entries.isEmpty {
                Text("Add an expense above to keep your balance up to date.").font(.callout).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.vertical, 6)
            }
            ForEach(entries) { entry in
                Button { request(.editEntry(entry.id)) } label: {
                    MoneyRow(category: entry.category, title: entry.label,
                             note: [entry.category.map(Categories.name), entry.day == store.today ? "Today" : entry.day.localDate.formatted(.dateTime.month(.abbreviated).day())]
                                .compactMap { $0 }.joined(separator: " · "),
                             cents: entry.cents)
                }
                .buttonStyle(.plain).padding(.horizontal, 6)
                .help("Edit in the Pocket window")
                .accessibilityHint("Open to edit this entry")
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 2) {
            if store.connected {
                Button { Task { await store.syncNow() } } label: {
                    SyncStatusLabel().font(.caption).padding(.horizontal, 6).frame(height: 26).contentShape(Rectangle())
                }
                .buttonStyle(.plain).help("Sync now")
            } else {
                Text(store.loadError == nil ? "\(store.money.string(store.spentThisMonth)) spent this month" : "Saved data unavailable")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    .padding(.horizontal, 6)
            }
            Spacer(minLength: 4)
            Button { open("main") } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
            .buttonStyle(RoundButtonStyle())
            .help("Open the Pocket window · ⌘O")
            .accessibilityLabel("Open the Pocket window")
            Menu {
                Button("Open Pocket") { open("main") }
                Button("Plan") { request(.section(.plan)) }
                Button("Subscriptions") { request(.section(.subscriptions)) }
                Button(AppSection.insights.title) { request(.section(.insights)) }
                Divider()
                Button("Settings…") { request(.section(.settings)) }
                if store.connected { Link("Open Web App", destination: store.server.webLink(code: nil)) }
                Divider()
                Button("About Pocket") { AboutPanel.show() }
                Button("Check for Updates…") { UpdateChecker.shared.checkAndReport() }
                Button("Share Pocket…") { SharePocket.show() }
                Divider()
                Button("Quit Pocket") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            }
            .menuStyle(.button).buttonStyle(RoundButtonStyle()).menuIndicator(.hidden).fixedSize()
            .help("More")
            .accessibilityLabel("More")
        }
    }

    private func openOptions() { let draft = quick.draft; quick.reset(); request(.newEntry(draft)) }
    private func request(_ destination: WindowRequest) { store.windowRequest = destination; open("main") }
    private func open(_ id: String) { openWindow(id: id); NSApp.activate(ignoringOtherApps: true) }
}
