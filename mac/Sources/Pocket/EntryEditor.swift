import AppKit
import PocketCore
import SwiftUI

enum Frequency: String, CaseIterable, Identifiable {
    case once, weekly, biweekly, monthly, quarterly, yearly
    var id: String { rawValue }
    var cadence: Cadence? { Cadence(rawValue: rawValue) }
    var name: String {
        switch self {
        case .once: "Once"
        case .biweekly: "2 weeks"
        case .quarterly: "3 months"
        default: cadence!.name
        }
    }
}

struct EntryDraft: Equatable {
    var spent: Bool
    var amount: String
    var label: String
    var category: String?
}

/// Form state for adding or editing an entry or a repeating payment.
@MainActor
final class EditorState: ObservableObject {
    enum Mode: Equatable {
        case new
        case entry(Entry)
        case rule(Rule)
    }

    @Published var mode: Mode = .new
    @Published var spent = true {
        didSet {
            let allowed = (spent ? Categories.spending : Categories.income).map(\.id)
            if let c = category, c != Categories.start, !allowed.contains(c) { category = nil }
            if mode == .new && !confirmTouched { confirm = !spent }
        }
    }
    @Published var frequency: Frequency = .once
    @Published var amount = "" {
        didSet {
            if let sign = amount.first, sign == "+" || sign == "-" {
                let rest = String(amount.dropFirst())
                if !rest.hasPrefix("+") && !rest.hasPrefix("-") {
                    amount = rest
                    spent = sign == "-"
                }
            }
            if error != nil { error = nil }
        }
    }
    @Published var label = "" {
        didSet {
            guard !categoryTouched, mode == .new, let store else { return }
            if let c = store.ledger.guessCategory(for: label, income: !spent) { category = c }
        }
    }
    @Published var category: String?
    @Published var subscription: Bool?
    @Published var categoryTouched = false
    @Published var date = Date()
    @Published var times = ""
    @Published var confirm = false
    @Published var confirmTouched = false
    /// A one-time payment that is already due but hasn't arrived (or hasn't been paid) yet.
    @Published var awaiting = false
    @Published var savePreset = false
    @Published var error: String?
    @Published var saved = 0
    @Published var focusAmount = 0
    @Published var showDetails = false

    weak var store: Store?

    var day: Day { Day(date) }
    var isFuture: Bool { day > Day.today }
    /// "Still waiting for it": saved as a payment that waits in Overview from today on.
    var waitsNow: Bool { mode == .new && frequency == .once && !isFuture && awaiting }
    var isPlanned: Bool { frequency != .once || isFuture || waitsNow }
    var editingEntry: Bool { if case .entry = mode { return true } else { return false } }
    var editingRule: Rule? { if case .rule(let r) = mode { return r } else { return nil } }

    func reset() {
        mode = .new
        spent = true
        frequency = .once
        amount = ""
        label = ""
        category = nil
        subscription = nil
        categoryTouched = false
        date = Date()
        times = ""
        confirm = false
        confirmTouched = false
        awaiting = false
        savePreset = false
        error = nil
        showDetails = false
    }

    func load(_ e: Entry) {
        reset()
        showDetails = true
        mode = .entry(e)
        spent = e.cents < 0
        amount = Money.edit(e.cents)
        label = e.label
        category = e.category
        categoryTouched = true
        date = e.day.localDate
    }

    func load(_ r: Rule) {
        reset()
        showDetails = true
        mode = .rule(r)
        spent = r.cents < 0
        frequency = r.isOnce ? .once : Frequency(rawValue: r.cadence.rawValue) ?? .monthly
        amount = Money.edit(r.cents)
        label = r.label
        category = r.category
        categoryTouched = true
        date = r.next.localDate
        times = r.isOnce ? "" : r.remaining.map(String.init) ?? ""
        confirm = !r.auto
        confirmTouched = true
        subscription = r.subscription
    }

    func startSubscription() {
        reset()
        frequency = .monthly
        subscription = true
        category = "subscriptions"
        categoryTouched = true
        showDetails = true
        focusAmount += 1
    }

    /// Fill the form from a quick-add button that asks for the amount each time.
    func start(from p: Preset) {
        reset()
        spent = p.sign < 0
        label = p.label
        category = p.category
        categoryTouched = true
        focusAmount += 1
    }

    var draft: EntryDraft { EntryDraft(spent: spent, amount: amount, label: label, category: category) }

    func load(_ draft: EntryDraft) {
        reset()
        spent = draft.spent
        amount = draft.amount
        label = draft.label
        category = draft.category
        categoryTouched = draft.category != nil
        showDetails = true
        focusAmount += 1
    }

    @discardableResult
    func save() -> Bool {
        guard let store else { return false }
        let startingBalance = editingEntry && category == Categories.start
        guard let cents = Money.parse(amount, allowZero: startingBalance) else { error = "Enter an amount, like 9.99"; return false }
        let l = label.trimmed
        guard !l.isEmpty else { error = "Say what it was"; return false }
        let t = times.trimmed
        let count = t.isEmpty ? nil : Int(t)
        if frequency != .once && !t.isEmpty && !(1...1_000_000).contains(count ?? 0) {
            error = "Enter between 1 and 1,000,000 payments, or leave it empty."
            return false
        }
        let signed = spent ? -cents : cents
        let success: Bool
        switch mode {
        case .entry(var e):
            e.cents = signed
            e.label = l
            e.day = day
            e.category = category
            success = store.updateEntry(e)
        case .rule(let r):
            success = store.updateRule(r.id, cents: signed, label: l, cadence: frequency.cadence ?? .monthly, next: day,
                             left: frequency == .once ? 1 : count, category: category, auto: !confirm,
                             subscription: spent && frequency != .once ? subscription : (r.subscription == nil ? nil : false),
                             once: frequency == .once)
        case .new:
            if isPlanned {
                // A one-time entry in the future is a rule with a single payment, so it counts on its day.
                success = store.addRule(Rule(cents: signed, label: l, cadence: frequency.cadence ?? .monthly, anchor: day,
                                   total: frequency == .once ? 1 : count, auto: waitsNow ? false : !confirm, category: category,
                                   subscription: spent && frequency != .once ? subscription : nil))
            } else {
                let preset = savePreset ? Preset(label: l, cents: cents, sign: spent ? -1 : 1, category: category) : nil
                success = store.addEntry(cents: signed, label: l, day: day, category: category, preset: preset) != nil
            }
        }
        guard success else {
            error = "Couldn't save. Your entry is still here; try again."
            return false
        }
        reset()
        saved += 1
        focusAmount += 1
        return true
    }
}

private struct EntryBodyHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// A compact entry sheet with native fields and room for scheduling when needed.
struct EntryEditor: View {
    @EnvironmentObject var store: Store
    @ObservedObject var state: EditorState
    var onClose: (() -> Void)? = nil

    @FocusState private var focus: Field?
    @State private var confirmDelete = false
    @State private var bodyHeight: CGFloat = 300
    enum Field { case amount, label }

    private var categories: [PocketCore.Category] { state.spent ? Categories.spending : Categories.income }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text(title).font(.system(size: 20, weight: .semibold))
                Spacer(minLength: 8)
                Picker("Type", selection: $state.spent) {
                    Text("Spent").tag(true)
                    Text("Got money").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 204)
            }
            .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 20)

            ScrollView {
                fields
                    .padding(.horizontal, 24).padding(.bottom, 20)
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: EntryBodyHeight.self, value: proxy.size.height)
                    })
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(bodyHeight, maximumBodyHeight))
            .onPreferenceChange(EntryBodyHeight.self) { if $0 > 0 { bodyHeight = $0 } }

            Divider()
            HStack(spacing: 8) {
                if state.mode != .new {
                    Button("\(deleteTitle)…", role: .destructive) { confirmDelete = true }
                    if let rule = state.editingRule, !rule.isOnce {
                        Button(rule.active ? "Pause" : "Resume") {
                            guard store.setActive(rule.id, !rule.active) else { return }
                            state.reset()
                            onClose?()
                        }
                    }
                }
                Spacer()
                Button("Cancel") { state.reset(); onClose?() }.keyboardShortcut(.cancelAction)
                Button(buttonTitle) { state.save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(Money.parse(state.amount, allowZero: state.editingEntry && state.category == Categories.start) == nil)
            }
            .controlSize(.large)
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .background(Palette.bg)
        .confirmationDialog(deleteQuestion, isPresented: $confirmDelete) {
            Button(deleteTitle, role: .destructive) { performDelete() }
        } message: { Text(deleteMessage) }
        .onChange(of: state.focusAmount) { _, _ in focus = .amount }
        .onAppear { state.store = store; if state.mode == .new { focus = .amount } }
    }

    private var maximumBodyHeight: CGFloat {
        max(240, min(480, (NSScreen.main?.visibleFrame.height ?? 780) - 200))
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                fieldLabel("Amount")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(store.money.symbol).foregroundStyle(.secondary)
                    TextField("Amount", text: $state.amount, prompt: Text(store.money.placeholder))
                        .textFieldStyle(.plain)
                        .monospacedDigit()
                        .foregroundStyle(state.spent ? Color.primary : Palette.accent)
                        .focused($focus, equals: .amount)
                        .onSubmit { focus = .label }
                    Text(store.ledger.currency).font(.caption).foregroundStyle(.secondary)
                }
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(focus == .amount ? Palette.accent : Palette.line))
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Description")
                TextField("Description", text: $state.label, prompt: Text(placeholder))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .focused($focus, equals: .label)
                    .onSubmit { state.save() }
            }

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel(dateCaption)
                    DatePicker(dateCaption, selection: $state.date, displayedComponents: .date)
                        .labelsHidden().controlSize(.large)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Category")
                    Picker("Category", selection: Binding(get: { state.category }, set: {
                        state.category = $0
                        state.categoryTouched = true
                    })) {
                        if state.category == Categories.start { Text("Starting balance").tag(Optional(Categories.start)) }
                        Text("None").tag(String?.none)
                        Divider()
                        ForEach(categories) { Label($0.name, systemImage: $0.symbol).tag(Optional($0.id)) }
                    }
                    .labelsHidden().pickerStyle(.menu).controlSize(.large)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !state.editingEntry {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Repeat")
                        Picker("Repeat", selection: $state.frequency) {
                            ForEach(Frequency.allCases) { Text($0.cadence?.name ?? "Once").tag($0) }
                        }
                        .labelsHidden().pickerStyle(.menu).controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if state.frequency != .once {
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel(state.editingRule != nil ? "Payments left" : "Number of payments")
                            TextField(state.editingRule != nil ? "Payments left" : "Number of payments", text: $state.times, prompt: Text("No end"))
                                .textFieldStyle(.roundedBorder).controlSize(.large).monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if state.mode == .new && state.frequency == .once && !state.isFuture {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(state.spent ? "I haven't paid this yet" : "I'm still waiting for this money", isOn: $state.awaiting)
                        .toggleStyle(.checkbox)
                    Text(state.awaiting ? "Waits in Overview until you confirm the real amount and date. Your balance doesn't change until then."
                                        : state.spent ? "For a bill you owe but haven't paid." : "For money someone owes you, like a client payment or a refund.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if state.isPlanned && !state.editingEntry {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(state.spent ? "Confirm each payment" : "Confirm when money arrives",
                           isOn: Binding(get: { state.confirm }, set: { state.confirm = $0; state.confirmTouched = true }))
                        .toggleStyle(.checkbox)
                    Text(state.confirm ? "Waits in Overview until you confirm the real amount and date." : "Counts automatically on its date.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if state.spent && state.frequency != .once && !state.editingEntry {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Show in Subscriptions", isOn: Binding(
                        get: { state.subscription ?? (state.category == "subscriptions") },
                        set: { state.subscription = $0 }))
                        .toggleStyle(.checkbox)
                    Text("Keep its category. This uses the same payment in Plan.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if state.mode == .new && !state.isPlanned {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Also save as a quick-add button", isOn: $state.savePreset).toggleStyle(.checkbox)
                    Text("Use ⌘1 to ⌘9 for the first nine buttons.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let error = state.error {
                Text(error).font(.callout).foregroundStyle(Palette.negative)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Couldn't save. \(error)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
    }

    private var title: String {
        switch state.mode {
        case .new: return state.waitsNow ? (state.spent ? "Not paid yet" : "Waiting for money") : state.isPlanned ? "New payment" : "New entry"
        case .entry: return "Edit entry"
        case .rule: return "Edit payment"
        }
    }

    private var placeholder: String {
        if state.frequency != .once { return state.spent ? "e.g. Netflix, rent" : "e.g. Paycheck" }
        return state.spent ? "What was it?" : "Where's it from?"
    }

    private var dateCaption: String {
        if state.editingRule != nil { return state.frequency == .once ? "Expected on" : "Next payment" }
        if state.frequency == .once { return state.isFuture ? (state.spent ? "Planned for" : "Expected on") : state.awaiting ? "Due" : "Date" }
        return state.spent ? "First payment" : "First payday"
    }

    private var buttonTitle: String {
        if state.mode != .new { return "Save" }
        if state.frequency != .once { return "Add Repeating" }
        if state.waitsNow { return "Add to Waiting" }
        return state.isFuture ? (state.spent ? "Add Planned" : "Add Expected") : (state.spent ? "Add Spending" : "Add Money In")
    }

    private var hint: String? {
        guard state.mode == .new else { return nil }
        if state.frequency != .once { return "Leave the number of payments empty if it never ends." }
        if state.isFuture { return "Shows in Plan until its date." }
        return nil
    }

    private var deleteTitle: String {
        switch state.mode {
        case .rule(let r): r.isOnce ? "Remove" : "Stop repeating"
        default: "Delete"
        }
    }

    private var deleteQuestion: String {
        switch state.mode {
        case .entry(let e): "Delete “\(e.label)”?"
        case .rule(let r): r.isOnce ? "Remove expected “\(r.label)”?" : "Stop “\(r.label)”?"
        case .new: ""
        }
    }

    private var deleteMessage: String {
        switch state.mode {
        case .entry(let e): "\(store.money.string(e.cents, signed: true)) on \(e.day.localDate.formatted(date: .abbreviated, time: .omitted)). This can't be undone."
        case .rule: "Payments already logged stay in your history."
        case .new: ""
        }
    }

    private func performDelete() {
        switch state.mode {
        case .entry(let e): guard store.deleteEntry(e.id) else { return }
        case .rule(let r): guard store.removeRule(r.id) else { return }
        case .new: break
        }
        state.reset()
        onClose?()
    }
}
