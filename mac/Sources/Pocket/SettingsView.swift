import AppKit
import PocketCore
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @ObservedObject private var updates = UpdateChecker.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var confirmErase = false
    @State private var pendingImport: URL?
    @State private var pendingRestore: Backup?
    @State private var message: String?

    private static let currencies: [String] = {
        let common = ["USD", "EUR", "GBP", "CAD", "AUD", "MXN", "COP", "ARS", "BRL", "CLP", "PEN", "JPY", "KRW", "CHF", "INR"]
        let rest = Locale.commonISOCurrencyCodes.filter { !common.contains($0) }.sorted()
        return common + rest
    }()

    var body: some View {
        Form {
            SyncSection()

            Section {
                Picker("Currency", selection: Binding(get: { store.ledger.currency }, set: { store.setCurrency($0) })) {
                    ForEach(Self.currencies, id: \.self) { code in
                        Text("\(code) · \(Locale.current.localizedString(forCurrencyCode: code) ?? code)").tag(code)
                    }
                }
            } header: {
                Text("Money")
            } footer: {
                Text("Changing currency changes how amounts are displayed. It doesn't convert your entries.")
            }

            Section {
                if store.ledger.presets.isEmpty {
                    Text("No buttons yet. Add one here, or choose Save as Button after you add an entry.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.ledger.presets) { p in PresetRow(preset: p) }
                    .onMove(perform: store.connected ? nil : { store.movePresets(from: $0, to: $1) })
                HStack {
                    Spacer()
                    Menu("Add Button") {
                        Button("Spending Button") { store.savePreset(Preset(label: "New button", cents: nil, sign: -1, category: nil)) }
                        Button("Money In Button") { store.savePreset(Preset(label: "Got paid", cents: nil, sign: 1, category: "pay")) }
                    }
                    .fixedSize()
                }
            } header: {
                Text("Quick-add buttons")
            } footer: {
                Text("⌘1 to ⌘9 use the first nine. Leave the amount empty for things that cost something different each time."
                     + " Save each button after editing."
                     + (store.connected ? "" : " Drag to reorder."))
            }

            Section("General") {
                Toggle("Hide balance in the menu bar and Quick Entry", isOn: $store.hideDesktopBalance)
                Toggle("Remind me when a payment I'm waiting for is due", isOn: $store.reminders)
                Button("Send Test Reminder") { Task { await store.sendTestReminder() } }
                    .disabled(!store.notificationServicesAvailable || !store.reminders || store.sendingTestReminder)
                    .help("Send a reminder in five seconds to check macOS notifications.")
                if let message = store.reminderMessage {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                } else if !store.notificationServicesAvailable {
                    Text("System notifications are disabled in this demo.").font(.callout).foregroundStyle(.secondary)
                }
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section {
                LabeledContent("Backup") {
                    HStack {
                        Button("Export…", action: export).disabled(store.loadError != nil)
                        if !store.connected { Button("Import…", action: chooseImport) }
                    }
                }
                LabeledContent {
                    Button("Export CSV…") { message = saveCSV(store, entries: store.ledger.sortedEntries, name: "Pocket \(store.today.iso)") }
                        .disabled(store.loadError != nil || store.ledger.entries.isEmpty)
                } label: {
                    Text("Spreadsheet")
                    Text("Every entry as a CSV file for Numbers, Excel or Google Sheets.")
                }
                if !store.connected {
                    LabeledContent {
                        let backups = store.backups
                        Menu("Restore…") {
                            ForEach(backups) { b in
                                Button(b.day.localDate.formatted(.dateTime.weekday(.wide).month(.wide).day())) { pendingRestore = b }
                            }
                            Divider()
                            Button("Show Backups in Finder") { store.showBackupsInFinder() }
                        }
                        .fixedSize()
                        .disabled(backups.isEmpty)
                    } label: {
                        Text("Daily backups")
                        Text(store.backups.isEmpty ? "The first one is made the next time something changes."
                             : "Pocket keeps a copy from each of the last 7 days it was used.")
                    }
                }
                LabeledContent("Data file") {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.fileURL]) }
                }
                if !store.connected {
                    LabeledContent("Start over") {
                        Button("Erase Everything…", role: .destructive) { confirmErase = true }
                    }
                }
                if let message { Text(message).foregroundStyle(.secondary) }
                SaveFailureView()
            } header: {
                Text("Your data")
            } footer: {
                Text(store.connected
                     ? "Synced with your account. This Mac keeps its own copy, with a daily backup for the last 7 days."
                     : "Everything stays on this Mac in one file, with a daily backup for the last 7 days. Nothing is sent anywhere.")
            }

            Section {
                LabeledContent("Version") {
                    HStack {
                        Text(UpdateChecker.currentVersion).monospacedDigit().foregroundStyle(.secondary)
                        Button("Check for Updates…") { updates.checkAndReport() }
                            .disabled(updates.checking)
                    }
                }
                LabeledContent("Pocket for Mac") {
                    Button("About Pocket") { AboutPanel.show() }
                }
            } header: {
                Text("About")
            } footer: {
                Text("Checking for updates asks GitHub for the latest release, only when you click it. Nothing about your money is sent.")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .confirmationDialog("Erase everything?", isPresented: $confirmErase) {
            Button("Erase everything", role: .destructive) {
                store.eraseEverything()
                message = store.saveError == nil ? "Everything was erased." : "Couldn't erase your data. Try again."
            }
        } message: {
            Text("All entries, repeating payments and buttons are deleted from this Mac. Export first if you want a copy.")
        }
        .confirmationDialog("Restore the backup from \(pendingRestore?.day.localDate.formatted(.dateTime.month(.wide).day()) ?? "")?", isPresented: Binding(
            get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }), presenting: pendingRestore) { backup in
            Button("Restore") { runRestore(backup) }
        } message: { _ in
            Text("What's in Pocket now is replaced by that day's copy. Export first if you want to keep it.")
        }
        .confirmationDialog("Replace your data with this file?", isPresented: Binding(
            get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }), presenting: pendingImport) { url in
            Button("Replace") { runImport(url) }
        } message: { _ in
            Text("What's in Pocket now is replaced by the file. Export first if you want to keep it.")
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Pocket \(Day.today.iso).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.export(to: url)
            message = "Exported to \(url.lastPathComponent)."
        } catch {
            message = "Couldn't export: \(error.localizedDescription)"
        }
    }

    private func chooseImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingImport = url
    }

    private func runRestore(_ backup: Backup) {
        do {
            try store.restore(backup)
            message = "Restored the backup from \(backup.day.localDate.formatted(.dateTime.month(.wide).day()))."
        } catch {
            message = "Couldn't restore: \(error.localizedDescription) Your saved data is unchanged."
        }
    }

    private func runImport(_ url: URL) {
        do {
            try store.importFile(url)
            message = "Imported \(url.lastPathComponent)."
        } catch {
            message = "Couldn't import: \(error.localizedDescription) Your saved data is unchanged."
        }
    }
}

/// Asks where to save a CSV of `entries`. Returns what to tell the person (nil when they cancel).
@MainActor
func saveCSV(_ store: Store, entries: [Entry], name: String) -> String? {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.commaSeparatedText]
    panel.nameFieldStringValue = name + ".csv"
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    do {
        try store.exportCSV(entries, to: url)
        return "Exported \(entries.count) \(entries.count == 1 ? "entry" : "entries") to \(url.lastPathComponent)."
    } catch {
        return "Couldn't export: \(error.localizedDescription)"
    }
}

/// A settings edit remains a draft until the whole button is valid and durably saved.
@MainActor
final class PresetEditorState: ObservableObject {
    @Published var label: String
    @Published var amount: String
    @Published var category: String?
    @Published private(set) var error: String?
    private var original: Preset

    init(_ preset: Preset) {
        original = preset
        label = preset.label
        amount = preset.cents.map(Money.edit) ?? ""
        category = preset.category
    }

    var hasChanges: Bool {
        label != original.label || amount != (original.cents.map(Money.edit) ?? "") || category != original.category
    }

    func revert(to preset: Preset) {
        original = preset
        label = preset.label
        amount = preset.cents.map(Money.edit) ?? ""
        category = preset.category
        error = nil
    }

    func refresh(_ preset: Preset) {
        if !hasChanges { revert(to: preset) }
    }

    @discardableResult
    func save(in store: Store) -> Bool {
        guard !label.trimmed.isEmpty else { error = "Give this button a name."; return false }
        let cents = Money.parse(amount)
        guard amount.trimmed.isEmpty || cents != nil else {
            error = "Enter an amount, like 6.50, or leave it empty to ask each time."
            return false
        }
        // Preserve changes arriving from sync while this row is being edited.
        guard var preset = store.ledger.presets.first(where: { $0.id == original.id }) else {
            error = "This button was removed. Add a new one to save these details."
            return false
        }
        if label != original.label { preset.label = label.trimmed }
        if amount != (original.cents.map(Money.edit) ?? "") { preset.cents = cents }
        if category != original.category { preset.category = category }
        guard store.savePreset(preset) else { error = "Couldn't save. Your edits are still here; try again."; return false }
        revert(to: preset)
        return true
    }
}

struct PresetRow: View {
    @EnvironmentObject var store: Store
    let preset: Preset
    @StateObject private var editor: PresetEditorState

    init(preset: Preset) {
        self.preset = preset
        _editor = StateObject(wrappedValue: PresetEditorState(preset))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                CategoryIcon(category: editor.category, cents: preset.sign, size: 24)
                TextField("Button name", text: $editor.label, prompt: Text("Name"))
                    .textFieldStyle(.roundedBorder).labelsHidden()
                    .onSubmit { editor.save(in: store) }
                Button(role: .destructive) { store.deletePreset(preset.id) } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless).help("Delete this button")
                    .accessibilityLabel("Delete \(preset.label) quick-add button")
            }
            HStack(spacing: 10) {
                TextField("Button amount", text: $editor.amount, prompt: Text("Ask each time"))
                    .textFieldStyle(.roundedBorder).labelsHidden()
                    .frame(width: 110).monospacedDigit()
                    .onSubmit { editor.save(in: store) }
                Picker("Button category", selection: $editor.category) {
                    Text("No category").tag(String?.none)
                    ForEach(preset.sign > 0 ? Categories.income : Categories.spending) { Text($0.name).tag(Optional($0.id)) }
                }
                .labelsHidden().frame(maxWidth: 160)
                Spacer(minLength: 0)
                if editor.hasChanges {
                    Button("Revert") { editor.revert(to: preset) }
                    Button("Save") { editor.save(in: store) }.buttonStyle(.borderedProminent)
                }
            }
            if let error = editor.error {
                Text(error).font(.caption).foregroundStyle(Palette.negative)
            }
        }
        .onChange(of: preset) { _, value in editor.refresh(value) }
    }
}
