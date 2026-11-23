import Charts
import PocketCore
import SwiftUI

struct PlanView: View {
    @EnvironmentObject var store: Store
    var onEdit: (EditTarget) -> Void
    @State private var previewWithoutOverdueIncome = false
    @State private var showAll = false
    @State private var pendingStop: Rule?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let p = store.projection(includeOverdueIncome: !previewWithoutOverdueIncome)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(p)
                if p.overdueIncome > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(previewWithoutOverdueIncome
                             ? "This preview leaves out \(store.money.string(p.overdueIncome)) in overdue income."
                             : "This forecast counts \(store.money.string(p.overdueIncome)) in overdue income as arriving today.")
                        Toggle("Preview without overdue income", isOn: $previewWithoutOverdueIncome)
                            .toggleStyle(.checkbox)
                    }
                    .font(.callout)
                }
                SaveFailureView()
                PaydayCard()
                Card {
                    ForecastChart(projection: p, money: store.money)
                        .frame(height: 240)
                        .padding(14)
                    everyday
                }
                comingUp(p)
                repeating
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 32).padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: p.overdueIncome) { _, amount in
            if amount == 0 { previewWithoutOverdueIncome = false }
        }
        .confirmationDialog("Stop “\(pendingStop?.label ?? "")”?", isPresented: Binding(
            get: { pendingStop != nil }, set: { if !$0 { pendingStop = nil } }), presenting: pendingStop) { r in
            Button(r.isOnce ? "Remove" : "Stop Repeating", role: .destructive) { store.removeRule(r.id) }
        } message: { _ in
            Text("Payments already logged stay in your history.")
        }
    }

    private func header(_ p: Projection) -> some View {
        let t = p.runway.text(store.range)
        let d = { (day: Day) in day.localDate.formatted(.dateTime.month(.abbreviated).day()) }
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) { forecastSummary(p, text: t, date: d); rangePicker }
            VStack(alignment: .leading, spacing: 14) { forecastSummary(p, text: t, date: d); rangePicker }
        }
    }

    private func forecastSummary(_ p: Projection, text t: (lead: String, strong: String), date d: (Day) -> String) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(t.lead) \(t.strong)")
                    .font(.display(26, .semibold)).tracking(-0.3)
                    .foregroundStyle(p.runway.warn ? Palette.negative : Color.primary)
                Text("On \(d(p.end)): \(store.money.string(p.endBalance))"
                     + (p.lowBalance < p.start ? " · lowest \(store.money.string(p.lowBalance)) on \(d(p.lowDay))" : ""))
                    .foregroundStyle(.secondary).monospacedDigit()
                if !previewWithoutOverdueIncome, let months = store.monthsLeft {
                    Text(monthsLeftText(months)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Whether the forecast also counts what's usually spent day to day, and how much that is.
    @ViewBuilder
    private var everyday: some View {
        if let e = store.everyday {
            Divider().padding(.horizontal, 8)
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Count everyday spending")
                    Text("≈ \(store.money.string(e.perDay)) a day, from a typical week of your last \(e.weeks) weeks. Scheduled payments are counted separately.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("Count everyday spending", isOn: $store.includeEveryday)
                    .toggleStyle(.switch).labelsHidden()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        } else if store.hasRecordedEntries {
            Divider().padding(.horizontal, 8)
            Text("Your forecast uses scheduled payments. After at least two weeks with everyday purchases, Pocket can estimate your usual daily spending.")
                .font(.callout).foregroundStyle(.secondary)
                .padding(.horizontal, 14).padding(.vertical, 10)
        }
    }

    private var rangePicker: some View {
            Picker("Range", selection: $store.range) {
                Text("1M").tag(30)
                Text("3M").tag(91)
                Text("6M").tag(182)
                Text("1Y").tag(365)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 210)
    }

    @ViewBuilder
    private func comingUp(_ p: Projection) -> some View {
        let steps = p.steps.filter { !$0.occurrence.overdue }
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: "Coming up", meta: "Next \(rangeName(store.range))")
                Card {
                    ForEach(showAll ? steps : Array(steps.prefix(10))) { s in
                        let o = s.occurrence
                        HStack {
                            MoneyRow(category: o.category, title: o.label,
                                     note: o.day.localDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                                     cents: o.cents, rightNote: "then \(store.money.string(s.after))", rightNegative: s.after < 0)
                            if o.isNext { NextActions(occurrence: o) }
                        }
                    }
                    if steps.count > 10 {
                        Button(showAll ? "Show less" : "Show all \(steps.count)") { withAnimation(reduceMotion ? nil : .snappy) { showAll.toggle() } }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(10)
                    }
                }
            }
        }
    }

    private var repeating: some View {
        let rules = store.ledger.liveRules
        var outM = 0.0, inM = 0.0
        for r in rules where r.active && !r.isOnce {
            let m = Double(abs(r.cents)) * r.cadence.perMonth
            if r.cents < 0 { outM += m } else { inM += m }
        }
        var parts: [String] = []
        if outM > 0 { parts.append("\(store.money.whole(Int(outM))) out") }
        if inM > 0 { parts.append("\(store.money.whole(Int(inM))) in") }

        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Repeating & expected", meta: parts.isEmpty ? nil : "≈ " + parts.joined(separator: " · ") + " a month")
            if rules.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Nothing planned yet. Add your bills, subscriptions and paychecks with a repeat schedule, or money you expect on a later date.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Plan a Payment…") { onEdit(EditTarget(kind: .new(nil))) }
                }
                .padding(.vertical, 12)
            } else {
                Card {
                    ForEach(rules) { r in
                        let when = r.isOnce
                            ? "One time · \(r.next.localDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))"
                            : "\(r.cadence.name) · next \(r.next.localDate.formatted(.dateTime.month(.abbreviated).day()))"
                                + (r.remaining.map { $0 == 1 ? " · last one" : " · \($0) left" } ?? "")
                        HStack(spacing: 2) {
                            Button { onEdit(EditTarget(kind: .rule(r))) } label: {
                                MoneyRow(category: r.category, symbol: r.isOnce ? "clock" : (r.category == nil ? "repeat" : nil), title: r.label,
                                     tag: !r.active ? "paused" : !r.auto ? "you confirm" : nil,
                                     note: when, cents: r.cents,
                                     rightNote: r.isOnce ? "expected" : "per \(r.cadence.unit)", dimmed: !r.active)
                            }
                                .buttonStyle(.plain)
                                .help("Edit \(r.label)")
                                .accessibilityHint("Open to edit this scheduled payment")
                                .contextMenu { actions(r) }
                            Menu { actions(r) } label: {
                                Image(systemName: "ellipsis").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                            }
                            .menuStyle(.button).buttonStyle(RoundButtonStyle(size: 28)).menuIndicator(.hidden).fixedSize()
                            .help("Skip, pause or stop \(r.label)")
                            .accessibilityLabel("Actions for \(r.label)")
                        }
                    }
                }
            }
        }
    }
}

private struct PaydayCard: View {
    @EnvironmentObject var store: Store
    @State private var cushionText = ""

    private var maxPayday: Day { store.today.adding(days: 365) }
    private var suggestedPayday: Day? {
        store.ledger.upcoming(today: store.today, days: 365).first {
            $0.cents > 0 && $0.day > store.today
        }?.day
    }
    private var payday: Day? {
        if let chosen = Day(iso: store.paydayDate), chosen > store.today, chosen <= maxPayday { return chosen }
        return suggestedPayday
    }
    private var cushion: Cents? {
        let text = cushionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains("-") && !text.contains("−") else { return nil }
        return text.isEmpty ? 0 : Money.parse(text, allowZero: true)
    }

    var body: some View {
        if store.loadError == nil {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Available until payday").font(.headline)
                    if let payday {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 16) { inputs(payday) }
                            VStack(alignment: .leading, spacing: 8) { inputs(payday) }
                        }
                        if let cushion, let projection = store.ledger.projectBeforePayday(
                            today: store.today, payday: payday, everyday: store.everyday?.perDay ?? 0
                        ) {
                            let extra = projection.lowBalance - cushion
                            Text(extra < 0 ? "\(store.money.string(-extra)) short of your cushion" : "\(store.money.string(extra)) available to spend today")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(extra < 0 ? Palette.negative : Color.primary)
                            Text("Lowest projected balance before payday is \(store.money.string(projection.lowBalance)) on \(projection.lowDay.localDate.formatted(.dateTime.month(.abbreviated).day())).")
                                .font(.callout).foregroundStyle(.secondary)
                            Text((projection.everyday > 0 ? "Includes \(store.money.string(projection.everyday)) per day of usual spending. " :
                                  "Usual spending is unavailable until there’s enough history. ") + "Income awaiting confirmation is excluded.")
                                .font(.callout).foregroundStyle(.secondary)
                        } else {
                            Text("Enter a cushion of zero or more.").font(.callout).foregroundStyle(Palette.negative)
                        }
                    } else {
                        Text("Choose your next payday to see what you can spend before then.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Set Payday…") { store.paydayDate = store.today.adding(days: 7).iso }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear { cushionText = Money.edit(store.paydayCushion) }
            .onChange(of: cushionText) { if let cushion { store.paydayCushion = cushion } }
        }
    }

    @ViewBuilder private func inputs(_ payday: Day) -> some View {
        DatePicker("Payday", selection: Binding(get: { payday.localDate }, set: { store.paydayDate = Day($0).iso }),
                   in: store.today.adding(days: 1).localDate...maxPayday.localDate, displayedComponents: .date)
        HStack(spacing: 6) {
            Text("Keep at least \(store.money.symbol)")
            TextField("Cushion", text: $cushionText).frame(width: 95)
        }
        if !store.paydayDate.isEmpty, suggestedPayday != nil {
            Button("Use Next Scheduled Income") { store.paydayDate = "" }.buttonStyle(.link)
        }
    }
}

extension PlanView {
    /// Edit, skip the next one, pause or stop: the same actions in the ⋯ menu and on right-click.
    @ViewBuilder
    func actions(_ r: Rule) -> some View {
        Button("Edit…") { onEdit(EditTarget(kind: .rule(r))) }
        if !r.isOnce {
            Button("Skip \(r.next.localDate.formatted(.dateTime.month(.abbreviated).day()))") {
                store.skip(r.nextOccurrence(today: store.today))
            }
            .disabled(!r.active)
            Button(r.active ? "Pause" : "Resume") { store.setActive(r.id, !r.active) }
        }
        Divider()
        Button(r.isOnce ? "Remove…" : "Stop Repeating…", role: .destructive) { pendingStop = r }
    }
}

/// "Got it" (with the real amount and date) and "Skip" for the next payment of a rule.
struct NextActions: View {
    @EnvironmentObject var store: Store
    let occurrence: Occurrence
    @State private var open = false
    @State private var amount = ""
    @State private var date = Date()
    @State private var error: String?

    var body: some View {
        Button(occurrence.cents > 0 ? "Got it…" : "Paid…") { open = true }
            .controlSize(.small)
            .popover(isPresented: $open, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(occurrence.label).font(.headline)
                    Text("Log it now with the real amount and date, or skip this one.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        TextField("Amount", text: $amount).textFieldStyle(.roundedBorder).frame(width: 100)
                        DatePicker("Actual payment date", selection: $date, in: ...Date(), displayedComponents: .date).labelsHidden()
                    }
                    HStack {
                        Button("Skip this one") { if store.skip(occurrence) { open = false } else { error = "Couldn't save. Try again." } }
                        Spacer()
                        Button(occurrence.cents > 0 ? "Got it" : "Paid") {
                            guard let c = Money.parse(amount) else { error = "Enter the actual amount, like 9.99."; return }
                            guard store.settle(occurrence, cents: occurrence.cents < 0 ? -c : c, on: Day(date)) else { error = "Couldn't save. Try again."; return }
                            open = false
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    }
                    if let error { Text(error).font(.caption).foregroundStyle(Palette.negative) }
                }
                .padding(16)
                .frame(width: 300)
                .onAppear { amount = Money.edit(occurrence.cents); date = Date(); error = nil }
            }
    }
}

/// The projected balance: it jumps when a payment lands, and slopes down with everyday spending.
struct ForecastChart: View {
    let projection: Projection
    let money: Money
    @State private var selected: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Sample: Identifiable {
        let index: Int
        let date: Date
        let value: Double
        var id: Int { index }
    }

    /// The line, drawn explicitly: each payment adds a vertical jump on its day, and everyday spending
    /// (when counted) slopes it down in between.
    private var samples: [Sample] {
        var out: [Sample] = []
        for (i, p) in projection.points.enumerated() {
            // The balance just before the payment lands (distinct x keeps the order stable).
            if i > 0 { out.append(Sample(index: out.count, date: p.day.localDate.addingTimeInterval(-60), value: Double(p.before) / 100)) }
            out.append(Sample(index: out.count, date: p.day.localDate, value: Double(p.balance) / 100))
        }
        out.append(Sample(index: out.count, date: projection.end.localDate, value: Double(projection.endBalance) / 100))
        return out
    }

    private var selectedPoint: Projection.Point? {
        guard let selected else { return nil }
        return projection.points.last { $0.day.localDate <= selected } ?? projection.points.first
    }

    var body: some View {
        Chart {
            ForEach(samples) { s in
                AreaMark(x: .value("Day", s.date), y: .value("Balance", s.value), stacking: .unstacked)
                    .foregroundStyle(Palette.accent.opacity(0.1))
                LineMark(x: .value("Day", s.date), y: .value("Balance", s.value))
                    .foregroundStyle(Palette.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            ForEach(projection.points.dropFirst()) { p in
                PointMark(x: .value("Day", p.day.localDate), y: .value("Balance", Double(p.balance) / 100))
                    .foregroundStyle(p.balance < 0 ? Palette.negative : Palette.accent)
                    .symbolSize(36)
            }
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(Color.secondary.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1))
            if let p = selectedPoint {
                RuleMark(x: .value("Selected", p.day.localDate))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(money.string(p.balance)).font(.headline).monospacedDigit()
                                .foregroundStyle(p.balance < 0 ? Palette.negative : Color.primary)
                            Text(p.day == projection.today ? "Today" : p.day.localDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(p.events) { e in
                                Text("\(e.label) \(money.string(e.cents, signed: true))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(8)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.line))
                    }
            }
        }
        .chartXScale(domain: projection.today.localDate...projection.end.localDate)
        .chartXSelection(value: $selected)
        .chartYAxis {
            AxisMarks(position: .leading) { v in
                AxisGridLine().foregroundStyle(Palette.line)
                AxisValueLabel(anchor: .trailing) { if let d = v.as(Double.self) { Text(money.compact(Int(d * 100))) } }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), anchor: .top)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.5), value: projection.days)
        .accessibilityLabel("Projected balance until \(projection.end.localDate.formatted(date: .abbreviated, time: .omitted)), ending at \(money.string(projection.endBalance))")
    }
}
