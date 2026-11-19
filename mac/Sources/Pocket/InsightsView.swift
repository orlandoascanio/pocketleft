import PocketCore
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var store: Store
    var onEdit: (EditTarget) -> Void
    @State private var allTime = false
    @State private var month = Day.today.yearMonth
    @State private var historyQuery = EntryQuery()
    @State private var showingCategoryHistory = false
    @State private var choosingMonth = false
    @State private var pickerYear = Day.today.year
    @FocusState private var focusedCategory: String?

    var body: some View {
        if showingCategoryHistory {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    showingCategoryHistory = false
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .accessibilityHidden(true)
                        Text("Back to Categories")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .buttonStyle(CategoryNavigationButtonStyle())
                .keyboardShortcut("[", modifiers: .command)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if store.saveError != nil { SaveFailureView() }
                        HistoryView(query: $historyQuery, onEdit: onEdit)
                    }
                    .frame(maxWidth: 760)
                    .padding(.horizontal, 32).padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: 824)
            .frame(maxWidth: .infinity)
        } else {
            summary
        }
    }

    private var summary: some View {
        let last = store.today.yearMonth
        let first = min(store.ledger.firstMonth, last)
        let selected = min(max(month, first), last)
        let monthToDate = !allTime && selected == last
        let period = allTime ? nil : selected.first...(monthToDate ? store.today : selected.last)
        let s = store.ledger.summary(in: period)

        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    HStack(spacing: 4) {
                        Button { month = selected.adding(-1) } label: { Image(systemName: "chevron.left") }
                            .disabled(allTime || selected <= first)
                            .accessibilityLabel("Previous month")
                        if allTime {
                            Text("Since \(first.first.localDate.formatted(.dateTime.month(.wide).year()))")
                                .font(.display(20, .semibold))
                                .frame(minWidth: 180)
                        } else {
                            Button {
                                pickerYear = selected.year
                                choosingMonth = true
                            } label: {
                                HStack(spacing: 8) {
                                    Text(selected.first.localDate.formatted(.dateTime.month(.wide).year()))
                                        .font(.display(20, .semibold))
                                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                                }
                                .frame(minWidth: 164)
                            }
                            .help("Jump to a month")
                            .accessibilityHint("Opens a month picker")
                            .popover(isPresented: $choosingMonth, arrowEdge: .bottom) {
                                monthPicker(first: first, last: last, selected: selected)
                            }
                        }
                        Button { month = selected.adding(1) } label: { Image(systemName: "chevron.right") }
                            .disabled(allTime || selected >= last)
                            .accessibilityLabel("Next month")
                    }
                    .buttonStyle(CategoryNavigationButtonStyle())
                    Spacer()
                    Picker("Period", selection: $allTime) {
                        Text("Month").tag(false)
                        Text("All time").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 180)
                }

                HStack(spacing: 10) {
                    stat(monthToDate ? "Spent · Month to date" : "Spent", store.money.string(s.spent), size: 28, primary: true)
                    stat("Money in", store.money.string(s.income), size: 21)
                    stat("Balance change", store.money.string(s.net, signed: true), size: 17, negative: s.net < 0)
                        .help("Money in minus spending for the selected period")
                        .accessibilityHint("Money in minus spending for the selected period")
                }

                if !allTime, let previous = store.ledger.previousSpendingPeriod(for: selected, today: store.today) {
                    let prev = store.ledger.summary(in: previous)
                    let diff = s.spent - prev.spent
                    let name = previous.lowerBound.localDate.formatted(.dateTime.month(.wide))
                    Label(diff == 0 ? "Same spending as \(name)"
                          : "\(store.money.string(abs(diff))) \(diff > 0 ? "more" : "less") than \(name) (\(store.money.string(prev.spent)))",
                          systemImage: diff > 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                        .foregroundStyle(.secondary)
                }

                breakdown(title: "Where it went", rows: s.byCategory, total: s.spent, income: false, period: period,
                          empty: allTime ? "No spending yet." : "No spending in this period.")
                if !s.incomeByCategory.isEmpty {
                    breakdown(title: "Where it came from", rows: s.incomeByCategory, total: s.income, income: true, period: period, empty: "")
                }
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 32).padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
    }

    private func monthPicker(first: YearMonth, last: YearMonth, selected: YearMonth) -> some View {
        VStack(spacing: 10) {
            HStack {
                Button { pickerYear -= 1 } label: { Image(systemName: "chevron.left") }
                    .disabled(pickerYear <= first.year)
                    .accessibilityLabel("Previous year")
                Spacer()
                Text(String(pickerYear)).font(.headline)
                Spacer()
                Button { pickerYear += 1 } label: { Image(systemName: "chevron.right") }
                    .disabled(pickerYear >= last.year)
                    .accessibilityLabel("Next year")
            }
            .buttonStyle(CategoryNavigationButtonStyle())

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                ForEach(1...12, id: \.self) { number in
                    let choice = YearMonth(year: pickerYear, month: number)
                    Button {
                        month = choice
                        choosingMonth = false
                    } label: {
                        Text(choice.first.localDate.formatted(.dateTime.month(.abbreviated)))
                            .font(.callout.weight(choice == selected ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CategoryNavigationButtonStyle(selected: choice == selected))
                    .disabled(choice < first || choice > last)
                    .accessibilityLabel(choice.first.localDate.formatted(.dateTime.month(.wide).year()))
                    .accessibilityAddTraits(choice == selected ? .isSelected : [])
                }
            }
        }
        .padding(12)
        .frame(width: 240)
    }

    private func breakdown(title: String, rows: [CategoryTotal], total: Cents, income: Bool, period: ClosedRange<Day>?, empty: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: title, meta: nil)
            if rows.isEmpty {
                Text(empty).foregroundStyle(.secondary).padding(.vertical, 16)
            } else {
                Card {
                    ForEach(rows) { c in
                        let focusID = "\(income)-\(c.id)"
                        Button {
                            historyQuery = EntryQuery(kind: income ? .income : .spending, category: c.category,
                                                      from: period?.lowerBound, to: period?.upperBound)
                            showingCategoryHistory = true
                        } label: {
                            CategoryBar(total: c, share: total > 0 ? Double(c.cents) / Double(total) : 0,
                                        income: income, showsBar: !income || rows.count > 1)
                        }
                        .buttonStyle(.plain)
                        .focusable()
                        .focusEffectDisabled()
                        .focused($focusedCategory, equals: focusID)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Palette.accent, lineWidth: focusedCategory == focusID ? 2 : 0)
                                .allowsHitTesting(false)
                        }
                        .help(c.category == Categories.uncategorized ? "Review uncategorized entries" : "Show these in History")
                    }
                }
            }
        }
    }

    private func stat(_ k: String, _ v: String, size: CGFloat, primary: Bool = false, negative: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(k).font(.caption).foregroundStyle(.secondary)
            Text(v).font(.display(size, primary ? .bold : .semibold)).monospacedDigit()
                .foregroundStyle(negative ? Palette.negative : Color.primary)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 51, alignment: .leading)
        .padding(14)
        .background(primary ? Palette.accent.opacity(0.07) : Palette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(primary ? Palette.accent.opacity(0.2) : Palette.line))
    }
}

private struct CategoryNavigationButtonStyle: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        Control(configuration: configuration, selected: selected)
    }

    private struct Control: View {
        let configuration: Configuration
        let selected: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(Palette.accent.opacity(isEnabled ? 1 : 0.35))
                .padding(.horizontal, 8)
                .frame(minWidth: 30, minHeight: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Palette.accent.opacity(backgroundOpacity))
                )
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onHover { hovering = $0 }
        }

        private var backgroundOpacity: Double {
            guard isEnabled else { return 0 }
            if configuration.isPressed { return 0.16 }
            if selected { return 0.12 }
            return hovering ? 0.08 : 0
        }
    }
}

struct CategoryBar: View {
    @EnvironmentObject var store: Store
    let total: CategoryTotal
    let share: Double
    let income: Bool
    let showsBar: Bool
    @State private var hovering = false

    var body: some View {
        let sign: Cents = income ? 1 : -1
        let noun = income ? (total.count == 1 ? "payment" : "payments") : (total.count == 1 ? "purchase" : "purchases")
        let percent = Int((share * 100).rounded())
        let count = "\(total.count) \(noun)"
        let name = Categories.name(total.category)
        let amount = store.money.string(total.cents)
        let needsReview = total.category == Categories.uncategorized
        let tint = Categories.tint(total.category, cents: sign)
        HStack(spacing: 12) {
            CategoryIcon(category: total.category, cents: sign, symbol: needsReview ? "tag" : nil)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name).fontWeight(.medium)
                    Text(showsBar ? "\(percent)% · \(count)" : count)
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if needsReview {
                        Text("Review").font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                    }
                    Text(amount).fontWeight(.medium).monospacedDigit()
                }
                if showsBar {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(tint.opacity(0.12))
                            Capsule().fill(tint).frame(width: g.size.width * share)
                        }
                    }
                    .frame(height: 6)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hovering ? Color.primary.opacity(0.05) : .clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(amount), \(percent)% of \(income ? "money in" : "spending"), \(count)")
        .accessibilityHint(needsReview ? "Review uncategorized entries" : "Open category history")
    }
}
