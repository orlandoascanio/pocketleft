import PocketCore
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: Store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var query: EntryQuery
    var onEdit: (EditTarget) -> Void

    @State private var pendingDelete: Entry?
    @State private var exportMessage: String?
    @State private var choosingDates = false
    @State private var historySnapshot = HistorySnapshot()
    @State private var historyLimit = 100
    @FocusState private var searchFocused: Bool

    var body: some View {
        history
            .onChange(of: store.ledger.entries, initial: true) { _, entries in
                historySnapshot = HistorySnapshot(entries: entries, query: query)
                historyLimit = 100
            }
            .onChange(of: query) { _, value in
                historySnapshot.filter(value)
                historyLimit = 100
                exportMessage = nil
            }
            .confirmationDialog("Delete “\(pendingDelete?.label ?? "")”?", isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), presenting: pendingDelete) { e in
                Button("Delete", role: .destructive) { store.deleteEntry(e.id) }
            } message: { e in
                Text("\(store.money.string(e.cents, signed: true)) on \(e.day.localDate.formatted(date: .abbreviated, time: .omitted)). This can't be undone.")
            }
    }

    private var history: some View {
        let all = historySnapshot.entries
        let after = historySnapshot.balanceAfter
        let shown = historySnapshot.matching
        let groups = Dictionary(grouping: Array(shown.prefix(historyLimit)), by: \.day).sorted { $0.key > $1.key }

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "History", meta: query.isEmpty ? nil : resultsMeta(shown)).padding(.top, 6)
            if !all.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        searchField
                        filterMenus
                        historyActions(shown)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            searchField
                            historyActions(shown)
                        }
                        HStack(spacing: 8) { filterMenus }
                    }
                }
                .background {
                    Button("Search History") { searchFocused = true }
                        .keyboardShortcut("f", modifiers: .command)
                        .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
                }
            }
            if let exportMessage { Text(exportMessage).font(.callout).foregroundStyle(.secondary).padding(.horizontal, 4) }
            if groups.isEmpty {
                Text(all.isEmpty ? "Nothing here yet. Add your first entry to get started." : "Nothing matches. Try other words or clear the filters.")
                    .foregroundStyle(.secondary).padding(.vertical, 20).frame(maxWidth: .infinity)
            }
            ForEach(groups, id: \.key) { day, entries in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(day == store.today ? "Today" : day == store.today.adding(days: -1) ? "Yesterday"
                             : day.localDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        let net = historySnapshot.netByDay[day] ?? 0
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
            if shown.count > historyLimit {
                Button("Show \(min(100, shown.count - historyLimit)) more") { historyLimit += 100 }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: store.ledger.entries.count)
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
        .padding(.horizontal, 10)
        .frame(minWidth: 180, minHeight: 32)
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
    private var filterMenus: some View {
        Menu {
            Picker("Show", selection: $query.kind) {
                ForEach(EntryQuery.Kind.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.inline).labelsHidden()
        } label: {
            filterLabel(query.kind == .all ? "All activity" : query.kind.name, icon: "arrow.up.arrow.down")
        }
            .menuStyle(.button).menuIndicator(.hidden)
            .buttonStyle(HistoryControlStyle(active: query.kind != .all)).fixedSize()
            .accessibilityLabel("Activity type")
            .accessibilityValue(query.kind.name)
            .help("Show spending, money in, or both")
        Menu {
            Picker("Category", selection: $query.category) {
                Text("Any category").tag(String?.none)
                Section("Spending") { ForEach(Categories.spending) { Label($0.name, systemImage: $0.symbol).tag(Optional($0.id)) } }
                Section("Money in") { ForEach(Categories.income) { Label($0.name, systemImage: $0.symbol).tag(Optional($0.id)) } }
                Text("Uncategorized").tag(Optional(Categories.uncategorized))
            }
            .pickerStyle(.inline).labelsHidden()
        } label: {
            filterLabel(query.category.map(Categories.name) ?? "Any category", icon: "tag")
        }
            .menuStyle(.button).menuIndicator(.hidden)
            .buttonStyle(HistoryControlStyle(active: query.category != nil)).fixedSize()
            .accessibilityLabel("Category")
            .accessibilityValue(query.category.map(Categories.name) ?? "Any category")
            .help("Show one category")
        Menu {
            Button("Any time") { query.from = nil; query.to = nil }
            Divider()
            ForEach(EntryQuery.Period.allCases) { p in
                Button(p.name) { (query.from, query.to) = p.range(today: store.today) }
            }
            Divider()
            Button("Choose Dates…") { choosingDates = true }
        } label: { filterLabel(periodTitle, icon: "calendar") }
            .menuStyle(.button).menuIndicator(.hidden)
            .buttonStyle(HistoryControlStyle(active: query.from != nil || query.to != nil)).fixedSize()
            .accessibilityLabel("Date range")
            .accessibilityValue(periodTitle)
            .help("Show a date range")
            .popover(isPresented: $choosingDates, arrowEdge: .bottom) { datesPopover }
    }

    private func filterLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).accessibilityHidden(true)
            Text(title)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private func historyActions(_ shown: [Entry]) -> some View {
        HStack(spacing: 8) {
            if !query.isEmpty {
                Button("Clear filters") { query = EntryQuery() }
                    .buttonStyle(HistoryControlStyle())
                    .help("Clear the search and all History filters")
            }
            Button {
                exportMessage = saveCSV(store, entries: shown, name: "Pocket \(query.isEmpty ? "" : "search ")\(store.today.iso)")
            } label: {
                Label("CSV", systemImage: "arrow.down.to.line")
            }
            .buttonStyle(HistoryControlStyle())
            .help(query.isEmpty ? "Export History as CSV" : "Export these \(shown.count) entries as CSV")
            .accessibilityLabel("Export as CSV")
            .disabled(shown.isEmpty)
        }
        .fixedSize()
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

private struct HistoryControlStyle: ButtonStyle {
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        Control(configuration: configuration, active: active)
    }

    private struct Control: View {
        let configuration: Configuration
        let active: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 8)
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(active ? Palette.accent : Color.primary)
                .padding(.horizontal, 9)
                .frame(minHeight: 32)
                .background {
                    shape.fill(Palette.surface)
                    shape.fill((active ? Palette.accent : Color.primary).opacity(tintOpacity))
                }
                .overlay(shape.strokeBorder(active ? Palette.accent.opacity(0.24) : Palette.line))
                .contentShape(shape)
                .opacity(isEnabled ? 1 : 0.48)
                .onHover { hovering = $0 }
        }

        private var tintOpacity: Double {
            if configuration.isPressed { return 0.16 }
            if hovering && isEnabled { return 0.09 }
            return active ? 0.05 : 0
        }
    }
}
