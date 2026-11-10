import AppKit
import PocketCore
import SwiftUI

struct EditTarget: Identifiable {
    /// An existing entry or plan, or a new entry (optionally carrying what was typed in the menu).
    enum Kind { case entry(Entry), rule(Rule), new(EntryDraft?), subscription }
    let kind: Kind
    let id = UUID()
}

extension Projection.Runway {
    func text(_ range: Int) -> (lead: String, strong: String) {
        let d = { (day: Day) in day.localDate.formatted(.dateTime.month(.abbreviated).day()) }
        switch self {
        case .backAboveOnce(let label): return ("Back above zero once", "\(label) pays")
        case .backAboveOn(let day): return ("Back above zero on", d(day))
        case .belowForWholeRange: return ("Below zero for the next", rangeName(range))
        case .runsOut(let day): return ("Runs out on", d(day))
        case .lastsPast(let day): return ("Lasts past", d(day))
        }
    }
}

func rangeName(_ days: Int) -> String {
    switch days {
    case ...31: "month"
    case ...92: "3 months"
    case ...183: "6 months"
    default: "year"
    }
}

/// "About 7 months of money at your usual pace."
func monthsLeftText(_ months: Double) -> String {
    let pace = "of money at your usual pace"
    if months < 1 { return "Less than a month \(pace)" }
    if months < 24 { let n = Int(months.rounded()); return "About \(n) month\(n == 1 ? "" : "s") \(pace)" }
    return "About \(Int(months / 12)) years \(pace)"
}

struct RunwayLine: View {
    var runway: Projection.Runway
    var range = 91
    var body: some View {
        let t = runway.text(range)
        HStack(spacing: 5) {
            Image(systemName: runway.warn ? "chart.line.downtrend.xyaxis" : "chart.line.uptrend.xyaxis")
                .foregroundStyle(.secondary)
            Text(t.lead)
            Text(t.strong).fontWeight(.semibold).foregroundStyle(runway.warn ? Palette.negative : Color.primary)
        }
    }
}

struct MainWindow: View {
    @EnvironmentObject var store: Store
    @State private var section: AppSection = .overview
    @StateObject private var editor = EditorState()
    @State private var editTarget: EditTarget?
    @State private var query = EntryQuery()
    @State private var waitingExpanded = false
    @State private var scrollTarget: String?
    @State private var hoveredSection: AppSection?
    @FocusState private var focusedSection: AppSection?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 4) {
                    ForEach([AppSection.overview, .plan, .subscriptions, .insights]) { s in
                        sidebarRow(s)
                    }
                }
                sidebarRow(.settings)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.bg)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Sidebar")
            .focusSection()
            .onMoveCommand { direction in
                let step: Int
                switch direction {
                case .up: step = -1
                case .down: step = 1
                default: return
                }
                let sections = AppSection.allCases
                guard let current = sections.firstIndex(of: focusedSection ?? section),
                      sections.indices.contains(current + step) else { return }
                section = sections[current + step]
                focusedSection = section
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                if store.loadError != nil && section != .settings {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your balance is unavailable").font(.title2.weight(.semibold))
                        SaveFailureView()
                        Button("Open Settings to Restore a Backup") { section = .settings }
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                switch section {
                case .overview: OverviewView(editor: editor, query: $query, waitingExpanded: $waitingExpanded, scrollTarget: $scrollTarget, onEdit: { editTarget = $0 })
                case .plan: PlanView(onEdit: { editTarget = $0 })
                case .subscriptions: SubscriptionsView(onEdit: { editTarget = $0 })
                case .insights: InsightsView(onShow: { cat, month in
                        query = EntryQuery(category: cat, month: month)
                        withAnimation(reduceMotion ? nil : .snappy) { section = .overview }
                    })
                case .settings: SettingsView()
                }
                }
            }
            .background(Palette.bg)
            .tint(Palette.accent)
            .navigationTitle(section.title)
        }
        .tint(Palette.accent)
        .toolbarBackground(Palette.bg, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar {
            Button { editTarget = EditTarget(kind: .new(nil)) } label: { Label("New Entry", systemImage: "plus") }
                .keyboardShortcut("n", modifiers: .command)
                .help("New entry with date, category and repeat · ⌘N")
                .disabled(store.loadError != nil)
        }
        .sheet(item: $editTarget) { EditSheet(target: $0) }
        .onAppear {
            editor.store = store
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            handle(store.windowRequest)
        }
        .onDisappear { NSApp.setActivationPolicy(.accessory) }
        .onChange(of: store.windowRequest) { _, r in handle(r) }
        // Focus entering the sidebar lands on the selected page, as in a native sidebar, and navigation
        // from the menu, a link or Categories moves it along with the selection.
        .onChange(of: focusedSection) { old, new in
            if old == nil, let new, new != section { focusedSection = section }
        }
        .onChange(of: section) { _, s in if focusedSection != nil { focusedSection = s } }
    }

    private func sidebarRow(_ item: AppSection) -> some View {
        let selected = section == item
        let foreground = selected ? (colorScheme == .dark ? Color.black : Color.white)
                                  : (colorScheme == .dark ? Color.white : Color.black)
        return Button {
            section = item
            focusedSection = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol).font(.system(size: 15, weight: .medium)).frame(width: 20)
                    .symbolRenderingMode(.monochrome).foregroundStyle(foreground)
                Text(item.title).font(.system(size: 14, weight: selected ? .semibold : .regular)).lineLimit(1)
                    .foregroundStyle(foreground)
                Spacer(minLength: 4)
                if item == .overview && !store.waiting.isEmpty {
                    Text("\(store.waiting.count)")
                        .font(.caption.weight(.semibold)).monospacedDigit()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(foreground.opacity(selected ? 0.16 : 0.08), in: Capsule())
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(foreground)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? Palette.accent : hoveredSection == item ? Color.primary.opacity(0.05) : .clear))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
        .focused($focusedSection, equals: item)
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Palette.accent, lineWidth: focusedSection == item ? 2 : 0)
            .padding(-3))
        .onHover { hoveredSection = $0 ? item : nil }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func handle(_ r: WindowRequest?) {
        guard let r else { return }
        store.windowRequest = nil
        switch r {
        case .section(let s): section = s
        case .newEntry(let draft):
            editTarget = EditTarget(kind: .new(draft))
        case .firstEntry:
            section = .overview
            query = EntryQuery()
            scrollTarget = "entry"
            DispatchQueue.main.async {
                editor.reset()
                editor.focusAmount += 1
            }
        case .quickAdd(let preset):
            section = .overview
            scrollTarget = "entry"
            // After the switch, so the Overview's amount field exists to take focus.
            DispatchQueue.main.async { editor.start(from: preset) }
        case .waiting:
            section = .overview
            waitingExpanded = true
            scrollTarget = "waiting"
        case .history:
            section = .overview
            query = EntryQuery()
            scrollTarget = "history"
        case .editEntry(let id):
            if let e = store.ledger.entries.first(where: { $0.id == id }) { editTarget = EditTarget(kind: .entry(e)) }
        case .editRule(let id):
            if let rule = store.ledger.rules.first(where: { $0.id == id }) { editTarget = EditTarget(kind: .rule(rule)) }
        }
    }
}

struct EditSheet: View {
    let target: EditTarget
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @StateObject private var state = EditorState()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SaveFailureView().padding(.horizontal, 20).padding(.top, 16)
            EntryEditor(state: state, onClose: { dismiss() })
        }
            .frame(width: 440)
            .fixedSize(horizontal: false, vertical: true)
            .tint(Palette.accent)
            .onAppear {
                state.store = store
                switch target.kind {
                case .entry(let e): state.load(e)
                case .rule(let r): state.load(r)
                case .new(let draft?): state.load(draft)
                case .new(nil): state.showDetails = true; state.focusAmount += 1
                case .subscription: state.startSubscription()
                }
            }
            .onChange(of: state.saved) { _, _ in dismiss() }
    }
}

// MARK: - Overview

struct OverviewView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var editor: EditorState
    @Binding var query: EntryQuery
    @Binding var waitingExpanded: Bool
    @Binding var scrollTarget: String?
    var onEdit: (EditTarget) -> Void
    @State private var pendingDelete: Entry?
    @State private var exportMessage: String?
    @State private var choosingDates = false
    @FocusState private var searchFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    hero
                    if store.saveError != nil { SaveFailureView() }
                    VStack(alignment: .leading, spacing: 10) {
                        if !store.hasRecordedEntries {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Keep your balance current").font(.headline)
                                Text("Add an expense or money you received. Your balance updates when you save.")
                                    .font(.callout).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if !store.ledger.presets.isEmpty { QuickBar(onAsk: { editor.start(from: $0) }) }
                        Composer(state: editor, amountSize: 30, showSaveTitle: !store.hasRecordedEntries, onMore: {
                            let draft = editor.draft
                            editor.reset()
                            onEdit(EditTarget(kind: .new(draft)))
                        })
                        if let error = editor.error {
                            Text(error).font(.callout).foregroundStyle(Palette.negative).padding(.horizontal, 4)
                        }
                        if store.receipt != nil { EntryReceiptView { store.windowRequest = $0 }.padding(.horizontal, 4) }
                    }
                    .frame(maxWidth: 520, alignment: .leading)
                    .id("entry")
                    if store.showSharePrompt { SharePromptView().frame(maxWidth: 520, alignment: .leading) }
                    if !store.waiting.isEmpty { waiting.id("waiting") }
                    history.id("history")
                }
                .frame(maxWidth: 700)
                .padding(.horizontal, 32).padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { proxy.scrollTo(target, anchor: .top) }
                scrollTarget = nil
            }
            .onAppear {
                if let target = scrollTarget { proxy.scrollTo(target, anchor: .top); scrollTarget = nil }
            }
        }
        .confirmationDialog("Delete “\(pendingDelete?.label ?? "")”?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), presenting: pendingDelete) { e in
            Button("Delete", role: .destructive) { store.deleteEntry(e.id) }
        } message: { e in
            Text("\(store.money.string(e.cents, signed: true)) on \(e.day.localDate.formatted(date: .abbreviated, time: .omitted)). This can't be undone.")
        }
    }

    private var hero: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Money left").font(.title3).foregroundStyle(.secondary)
                Text(store.loadError == nil ? store.money.string(store.balance) : "—")
                    .font(.display(60, .bold)).tracking(-1.2)
                    .monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.45)
                    .accessibilityLabel("Money left")
                    .accessibilityValue(store.loadError == nil ? store.money.string(store.balance) : "Unavailable until your saved data can be opened")
                    .contentTransition(.numericText(value: Double(store.balance)))
                    .foregroundStyle(store.balance < 0 ? Palette.negative : Color.primary)
                    .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0), value: store.balance)
                if store.loadError == nil {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 14) { balanceContext }
                        VStack(alignment: .leading, spacing: 6) { balanceContext }
                    }
                    .padding(.top, 2)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 12)
            PocketStage(width: 96)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var balanceContext: some View {
        Text("\(store.money.string(store.spentThisMonth)) spent this month")
            .foregroundStyle(.secondary).monospacedDigit().fixedSize()
        if let runway = store.runway {
            Button { store.windowRequest = .section(.plan) } label: {
                HStack(spacing: 4) {
                    RunwayLine(runway: runway, range: store.range)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open Plan to see the forecast")
        }
    }

    /// Money that was due and needs a "Got it" or a "Skip". A long list shows the oldest few first.
    private var waiting: some View {
        let all = store.waiting
        let shown = waitingExpanded ? all : Array(all.prefix(3))
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Waiting for you", meta: all.count == 1 ? "Did it arrive?" : "\(all.count) payments")
            ForEach(shown) { WaitingCard(occurrence: $0) }
            if all.count > 3 {
                Button(waitingExpanded ? "Show less" : "Show all \(all.count)") {
                    withAnimation(reduceMotion ? nil : .snappy) { waitingExpanded.toggle() }
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 6)
    }

    private var history: some View {
        let all = store.ledger.sortedEntries
        var after: [UUID: Cents] = [:]
        var run: Cents = 0
        for e in all.reversed() { run += e.cents; after[e.id] = run }
        let shown = query.isEmpty ? all : all.filter(query.matches)
        let groups = Dictionary(grouping: shown, by: \.day).sorted { $0.key > $1.key }

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "History", meta: query.isEmpty ? nil : resultsMeta(shown)).padding(.top, 6)
            if !all.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { searchField; filterMenus(shown) }
                    VStack(alignment: .leading, spacing: 8) { searchField; HStack(spacing: 8) { filterMenus(shown) } }
                }
                .background {
                    Button("Search History") { searchFocused = true }
                        .keyboardShortcut("f", modifiers: .command)
                        .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
                }
            }
            if let exportMessage { Text(exportMessage).font(.callout).foregroundStyle(.secondary).padding(.horizontal, 4) }
            if groups.isEmpty {
                Text(all.isEmpty ? "Nothing here yet. Add your first entry above." : "Nothing matches. Try other words or clear the filters.")
                    .foregroundStyle(.secondary).padding(.vertical, 20).frame(maxWidth: .infinity)
            }
            ForEach(groups, id: \.key) { day, entries in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(day == store.today ? "Today" : day == store.today.adding(days: -1) ? "Yesterday"
                             : day.localDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        let net = entries.reduce(0) { $0 + $1.cents }
                        Text(store.money.string(net, signed: true))
                            .font(.callout).monospacedDigit()
                            .foregroundStyle(net > 0 ? Palette.accent : Color.secondary)
                    }
                    .padding(.horizontal, 6)
                    Card {
                        ForEach(entries) { e in
                            let left = after[e.id] ?? 0
                            Button { onEdit(EditTarget(kind: .entry(e))) } label: {
                            MoneyRow(category: e.category, title: e.label,
                                     note: [e.category.map(Categories.name), e.ruleID != nil ? "Scheduled payment" : nil]
                                        .compactMap { $0 }.joined(separator: " · "),
                                     cents: e.cents, rightNote: "left \(store.money.string(left))", rightNegative: left < 0)
                            }
                                .buttonStyle(.plain)
                                .help("Edit \(e.label)")
                                .accessibilityHint("Open to edit this entry")
                                .contextMenu {
                                    Button("Edit…") { onEdit(EditTarget(kind: .entry(e))) }
                                    if store.canSaveAsPreset(e) {
                                        Button("Save as Quick-Add Button") { store.saveAsPreset(e.id) }
                                    }
                                    Divider()
                                    Button("Delete…", role: .destructive) { pendingDelete = e }
                                }
                                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                        }
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: store.ledger.entries.count)
        .onChange(of: query) { _, _ in exportMessage = nil }
    }

    private func resultsMeta(_ shown: [Entry]) -> String {
        let net = shown.reduce(0) { $0 + $1.cents }
        return "\(shown.count) \(shown.count == 1 ? "entry" : "entries") · \(store.money.string(net, signed: true))"
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search history", text: $query.text, prompt: Text("Search history"))
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onExitCommand { query.text = ""; searchFocused = false }
            if !query.text.isEmpty {
                Button { query.text = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.tertiary)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(minWidth: 200)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(searchFocused ? Palette.accent : Palette.line))
        .help("Search labels, categories and amounts · ⌘F")
    }

    private var periodTitle: String {
        if query.from == nil && query.to == nil { return "Any time" }
        if let p = query.period(today: store.today) { return p.name }
        if let m = query.month { return m.first.localDate.formatted(.dateTime.month(.wide).year()) }
        let d = { (day: Day?) in day?.localDate.formatted(.dateTime.month(.abbreviated).day()) ?? "…" }
        return "\(d(query.from)) – \(d(query.to))"
    }

    @ViewBuilder
    private func filterMenus(_ shown: [Entry]) -> some View {
        Menu {
            Picker("Show", selection: $query.kind) {
                ForEach(EntryQuery.Kind.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.inline).labelsHidden()
        } label: { Text(query.kind.name) }
            .menuStyle(.button).fixedSize()
            .help("Show spending, money in, or both")
        Menu {
            Picker("Category", selection: $query.category) {
                Text("Any category").tag(String?.none)
                Section("Spending") { ForEach(Categories.spending) { Label($0.name, systemImage: $0.symbol).tag(Optional($0.id)) } }
                Section("Money in") { ForEach(Categories.income) { Label($0.name, systemImage: $0.symbol).tag(Optional($0.id)) } }
            }
            .pickerStyle(.inline).labelsHidden()
        } label: { Text(query.category.map(Categories.name) ?? "Any category") }
            .menuStyle(.button).fixedSize()
            .help("Show one category")
        Menu {
            Button("Any time") { query.from = nil; query.to = nil }
            Divider()
            ForEach(EntryQuery.Period.allCases) { p in
                Button(p.name) { (query.from, query.to) = p.range(today: store.today) }
            }
            Divider()
            Button("Choose Dates…") { choosingDates = true }
        } label: { Text(periodTitle) }
            .menuStyle(.button).fixedSize()
            .help("Show a date range")
            .popover(isPresented: $choosingDates, arrowEdge: .bottom) { datesPopover }
        if !query.isEmpty {
            Button("Clear") { withAnimation(reduceMotion ? nil : .snappy) { query = EntryQuery() } }
                .help("Show everything")
        }
        Spacer(minLength: 0)
        Button { exportMessage = saveCSV(store, entries: shown, name: "Pocket \(query.isEmpty ? "" : "search ")\(store.today.iso)") } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .help(query.isEmpty ? "Export history as a CSV spreadsheet" : "Export these \(shown.count) entries as a CSV spreadsheet")
        .accessibilityLabel("Export as CSV")
        .disabled(shown.isEmpty)
    }

    private var datesPopover: some View {
        let from = Binding(get: { (query.from ?? store.today.yearMonth.first).localDate },
                           set: { query.from = Day($0); if let to = query.to, to < query.from! { query.to = query.from } })
        let to = Binding(get: { (query.to ?? store.today).localDate },
                         set: { query.to = Day($0); if let f = query.from, f > query.to! { query.from = query.to } })
        return Form {
            DatePicker("From", selection: from, displayedComponents: .date)
            DatePicker("To", selection: to, displayedComponents: .date)
        }
        .padding(16)
        .frame(width: 260)
        .onAppear {
            if query.from == nil { query.from = store.today.yearMonth.first }
            if query.to == nil { query.to = store.today }
        }
    }
}

/// A payment that was due but hasn't been confirmed. "Got it" (or "Paid") asks what actually
/// happened, prefilled with what was expected; "Skip" drops this one.
struct WaitingCard: View {
    @EnvironmentObject var store: Store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let occurrence: Occurrence
    var compact = false
    @State private var confirming = false
    @State private var amount = ""
    @State private var date = Date()
    @State private var error: String?
    @FocusState private var amountFocused: Bool

    init(occurrence: Occurrence, compact: Bool = false, initiallyExpanded: Bool = false, initialError: String? = nil) {
        self.occurrence = occurrence
        self.compact = compact
        _confirming = State(initialValue: initiallyExpanded)
        _error = State(initialValue: initialError)
    }

    private var income: Bool { occurrence.cents > 0 }
    private var confirmTitle: String { income ? "Got it" : "Paid" }

    private var due: String {
        let d = occurrence.day.localDate.formatted(.dateTime.month(.abbreviated).day())
        if occurrence.day == store.today { return "Due today" }
        return "Was due \(d)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                CategoryIcon(category: occurrence.category, cents: occurrence.cents, size: 32,
                             symbol: occurrence.category == nil ? "clock" : nil)
                VStack(alignment: .leading, spacing: 2) {
                    Text(occurrence.label).fontWeight(.medium).lineLimit(2)
                    Text(due).font(.caption).foregroundStyle(.secondary)
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                Text(store.money.string(occurrence.cents, signed: true))
                    .fontWeight(.medium).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                    .foregroundStyle(income ? Palette.accent : Color.primary)
                if !confirming {
                    Button("Skip", action: skip)
                        .help("Skip this payment. It won't count.")
                        .accessibilityLabel("Skip \(occurrence.label)")
                    Button(confirmTitle) { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { confirming = true } }
                        .buttonStyle(.borderedProminent)
                        .help(income ? "Log it with the amount and date it actually arrived" : "Log it with the amount and date you actually paid")
                        .accessibilityLabel("\(confirmTitle): \(occurrence.label)")
                }
            }
            if confirming {
                HStack(spacing: 8) {
                    Text(income ? "Arrived" : "Paid").foregroundStyle(.secondary)
                    TextField("Amount", text: $amount, prompt: Text(store.money.placeholder))
                        .textFieldStyle(.roundedBorder).frame(width: 110).monospacedDigit()
                        .focused($amountFocused)
                        .accessibilityLabel(income ? "Amount that arrived" : "Amount paid")
                        .onSubmit(confirm)
                    Text("on").foregroundStyle(.secondary)
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                        .labelsHidden().accessibilityLabel(income ? "Date it arrived" : "Date paid")
                    Spacer(minLength: 4)
                    Button("Cancel") {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { confirming = false }
                        error = nil
                    }
                    Button("Log It", action: confirm).buttonStyle(.borderedProminent)
                }
                .controlSize(.regular)
                .transition(.opacity)
                .onAppear { amountFocused = true }
            }
            if let error { Text(error).font(.caption).foregroundStyle(Palette.negative) }
        }
        .padding(compact ? 10 : 12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line))
        .accessibilityElement(children: .contain)
        .onAppear { amount = Money.edit(occurrence.cents) }
    }

    private func skip() {
        if !store.skip(occurrence) { error = "Couldn't skip this payment. Try again." }
    }

    private func confirm() {
        guard let cents = Money.parse(amount) else {
            error = "Enter the actual amount, like 9.99."
            return
        }
        guard store.settle(occurrence, cents: occurrence.cents < 0 ? -cents : cents, on: Day(date)) else {
            error = "Couldn't save this payment. Try again."
            return
        }
        error = nil
    }
}
