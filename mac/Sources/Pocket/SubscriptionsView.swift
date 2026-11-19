import PocketCore
import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject var store: Store
    var onEdit: (EditTarget) -> Void
    @State private var days = 30
    @State private var stopping: Rule?
    @State private var editingReminders: RenewalReminderTarget?

    var body: some View {
        let summary = SubscriptionSummary(ledger: store.ledger, today: store.today, days: days)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { heading; addButton }
                    VStack(alignment: .leading, spacing: 12) { heading; addButton }
                }
                SaveFailureView()
                if !summary.active.isEmpty || !summary.paused.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { totals(summary) }
                        VStack(spacing: 10) { totals(summary) }
                    }
                    subscriptionList("Your subscriptions", rules: summary.active, renewals: summary.renewals)
                    if !summary.overdue.isEmpty {
                        Button("Review overdue payments", systemImage: "clock.badge.exclamationmark") {
                            store.windowRequest = .waiting
                        }.buttonStyle(.link).padding(.horizontal, 4)
                    }
                    subscriptionList("Paused", rules: summary.paused)
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "repeat.circle").font(.system(size: 30)).foregroundStyle(Palette.accent)
                                .accessibilityHidden(true)
                            Text("No subscriptions yet").font(.headline)
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                reminders
                if !summary.otherRepeating.isEmpty {
                    DisclosureGroup {
                        Card {
                            ForEach(summary.otherRepeating) { rule in
                                HStack {
                                    MoneyRow(category: rule.category, title: rule.label, note: rule.cadence.name,
                                             cents: rule.cents, dimmed: !rule.active)
                                    Button("Include") { store.setSubscription(rule.id, true) }
                                        .help("Show \(rule.label) in Subscriptions without changing its category")
                                        .accessibilityLabel("Include \(rule.label) in Subscriptions")
                                        .padding(.trailing, 8)
                                }
                            }
                        }.padding(.top, 8)
                    } label: {
                        Text("Add from repeating payments (\(summary.otherRepeating.count))")
                            .font(.callout.weight(.medium))
                    }
                }
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 32).padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg)
        .tint(Palette.accent)
        .sheet(item: $editingReminders) { target in
            RenewalReminderEditor(target: target, reminders: reminders(for: target))
        }
        .alert("Delete the renewal schedule?", isPresented: Binding(
            get: { stopping != nil }, set: { if !$0 { stopping = nil } }), presenting: stopping) { rule in
            Button("Cancel", role: .cancel) {}
            Button("Delete Schedule", role: .destructive) { store.removeRule(rule.id) }
        } message: { rule in
            Text("Pocket will remove future charges and reminders for \(rule.label). Past payments stay in History.")
        }
    }

    private func reminders(for target: RenewalReminderTarget) -> [RenewalReminder] {
        switch target {
        case .defaults:
            return store.renewalReminders.defaults
        case .subscription(let id):
            let renewal = store.ledger.rules.first { $0.id == id }?.next
            return store.renewalReminders.reminders(for: id).filter { reminder in
                if case .relative = reminder { return true }
                return renewal.flatMap { reminder.date(for: $0) }.map { $0 > Date() } ?? false
            }
        }
    }

    private var heading: some View {
        Text("Subscriptions").font(.display(28, .semibold)).tracking(-0.3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private var addButton: some View {
        Button { onEdit(EditTarget(kind: .subscription(nil))) } label: {
            Label("Add Subscription", systemImage: "plus")
        }.buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(store.loadError != nil)
    }

    @ViewBuilder private func totals(_ summary: SubscriptionSummary) -> some View {
        stat(cents: summary.monthly) { Text("Monthly equivalent").foregroundStyle(.secondary) }
        stat(cents: summary.annual) { Text("Per year").foregroundStyle(.secondary) }
        stat(cents: summary.upcomingTotal, emphasized: true) {
            Menu {
                ForEach([7, 30], id: \.self) { period in
                    Button { days = period } label: {
                        if days == period {
                            Label("Next \(period) days", systemImage: "checkmark")
                        } else {
                            Text("Next \(period) days")
                        }
                    }
                }
            } label: {
                Text("Next \(days) days")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Renewal total period")
            .accessibilityValue("Next \(days) days")
        }
    }

    private func stat<Title: View>(cents: Cents, emphasized: Bool = false, @ViewBuilder title: () -> Title) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 7) {
                title().font(.callout).frame(height: 18, alignment: .leading)
                Text(store.money.string(cents)).font(.display(24, emphasized ? .bold : .semibold)).monospacedDigit()
                    .foregroundStyle(emphasized ? Palette.accent : Color.primary)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }.padding(12).frame(minWidth: 130, maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func subscriptionList(_ title: String, rules: [Rule], renewals: [Occurrence] = []) -> some View {
        if !rules.isEmpty {
            let bySubscription = Dictionary(grouping: renewals, by: \.ruleID)
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: title)
                Card {
                    ForEach(rules) { rule in
                        SubscriptionRow(rule: rule, upcoming: bySubscription[rule.id, default: []], windowDays: days,
                                        onEdit: { onEdit(EditTarget(kind: .subscription(rule))) },
                                        onReminders: { editingReminders = .subscription(rule.id) },
                                        onStop: { stopping = rule })
                    }
                }
            }
        }
    }

    private var reminders: some View {
        Card {
            HStack(spacing: 12) {
                CategoryIcon(category: nil, cents: -1, symbol: "bell")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me before renewals")
                    if store.subscriptionReminders {
                        Text(store.reminderMessage ?? "\(store.renewalReminders.defaults.count) per renewal by default")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if store.subscriptionReminders {
                    Button("Defaults…") { editingReminders = .defaults }
                        .accessibilityLabel("Change default renewal reminders")
                }
                Toggle("Remind me before renewals", isOn: $store.subscriptionReminders)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SubscriptionRow: View {
    @EnvironmentObject private var store: Store
    @State private var showingRenewal = false
    let rule: Rule
    let upcoming: [Occurrence]
    let windowDays: Int
    let onEdit: () -> Void
    let onReminders: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button {
                if rule.active { showingRenewal = true } else { onEdit() }
            } label: {
                MoneyRow(category: rule.category, title: rule.label,
                         note: rule.active ? Self.renewalLabel(rule.next, today: store.today) : "",
                         cents: rule.cents, rightNote: "per \(rule.cadence.unit)", dimmed: !rule.active,
                         noteDisclosure: rule.active)
            }
            .buttonStyle(.plain)
            .help(rule.active ? "Show renewal dates for \(rule.label)" : "Edit \(rule.label)")
            .contextMenu { managementActions }
            .popover(isPresented: $showingRenewal, arrowEdge: .bottom) { details }
            Menu {
                managementActions
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel("Manage \(rule.label)").padding(.trailing, 8)
        }
    }

    @ViewBuilder private var managementActions: some View {
        Button("Edit Subscription…", systemImage: "pencil", action: onEdit)
        if rule.active { Button("Renewal Reminders…", systemImage: "bell", action: onReminders) }
        Divider()
        Button(rule.active ? "Pause Tracking" : "Resume Tracking", systemImage: rule.active ? "pause.circle" : "play.circle") {
            store.setActive(rule.id, !rule.active)
        }
        Divider()
        Button(role: .destructive, action: onStop) {
            Label("Delete Schedule…", systemImage: "trash")
        }
    }

    static func renewalLabel(_ day: Day, today: Day) -> String {
        let offset = today.days(until: day)
        let style = Date.FormatStyle().month(.abbreviated).day()
        let date = day.localDate.formatted(day.year == today.year ? style : style.year())
        switch offset {
        case ..<0: return "Overdue since \(date)"
        case 0: return "Renews today"
        case 1: return "Renews tomorrow"
        case 2...7: return "Renews in \(offset) days"
        default: return "Renews \(date)"
        }
    }

    private var details: some View {
        let later = upcoming.filter { $0.day > rule.next }
        return VStack(alignment: .leading, spacing: 12) {
            Text(rule.label).font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.next < store.today ? "Overdue payment" : "Next renewal")
                    .font(.caption).foregroundStyle(.secondary)
                charge(on: rule.next, cents: rule.cents)
            }
            if !later.isEmpty {
                Divider()
                Text("Later in the next \(windowDays) days").font(.caption).foregroundStyle(.secondary)
                ForEach(later) { charge(on: $0.day, cents: $0.cents) }
            }
            Divider()
            HStack {
                Button("Reminders…") {
                    showingRenewal = false
                    onReminders()
                }
                Spacer()
                Button("Edit…") {
                    showingRenewal = false
                    onEdit()
                }
                .accessibilityLabel("Edit subscription")
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func charge(on day: Day, cents: Cents) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(day.localDate, format: .dateTime.weekday(.wide).month(.wide).day().year())
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text(store.money.string(cents, signed: true)).monospacedDigit().fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}
