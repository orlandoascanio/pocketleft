import PocketCore
import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject var store: Store
    var onEdit: (EditTarget) -> Void
    @State private var days = 30
    @State private var stopping: Rule?

    var body: some View {
        let summary = SubscriptionSummary(ledger: store.ledger, today: store.today, days: days)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { heading(summary); addButton }
                    VStack(alignment: .leading, spacing: 12) { heading(summary); addButton }
                }
                SaveFailureView()
                if !summary.active.isEmpty || !summary.paused.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { totals(summary) }
                        VStack(spacing: 10) { totals(summary) }
                    }
                    Text("Monthly and annual costs are equivalents at current prices. Paused subscriptions are excluded.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    subscriptionList("Your subscriptions", rules: summary.active)
                    upcoming(summary)
                    subscriptionList("Paused", rules: summary.paused)
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "repeat.circle").font(.system(size: 30)).foregroundStyle(Palette.accent)
                                .accessibilityHidden(true)
                            Text("All your subscriptions, in one place.").font(.headline)
                            Text("Add a subscription or choose a repeating payment below. See what it costs and when it renews, without logging it twice.")
                                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            addButton
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
        .confirmationDialog("Stop tracking “\(stopping?.label ?? "")”?", isPresented: Binding(
            get: { stopping != nil }, set: { if !$0 { stopping = nil } }), presenting: stopping) { rule in
            Button("Stop Tracking", role: .destructive) { store.removeRule(rule.id) }
        } message: { _ in
            Text("Future payments are removed from Pocket. Past payments stay in History. Cancel with the provider separately to stop being charged.")
        }
    }

    private func heading(_ summary: SubscriptionSummary) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Subscriptions").font(.display(28, .semibold)).tracking(-0.3)
            Text(summary.active.isEmpty && summary.paused.isEmpty
                 ? "Know what renews, and what it adds up to."
                 : "\(summary.active.count) active" + (summary.paused.isEmpty ? "" : " · \(summary.paused.count) paused"))
                .foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addButton: some View {
        Button { onEdit(EditTarget(kind: .subscription)) } label: {
            Label("Add Subscription", systemImage: "plus")
        }.buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(store.loadError != nil)
    }

    @ViewBuilder private func totals(_ summary: SubscriptionSummary) -> some View {
        stat("Per month", cents: summary.monthly)
        stat("Per year", cents: summary.annual)
        stat("Next \(days) days", cents: summary.upcomingTotal)
    }

    private func stat(_ title: String, cents: Cents) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.callout).foregroundStyle(.secondary)
                Text(store.money.string(cents)).font(.display(24, .semibold)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
            }.padding(12).frame(minWidth: 130, maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
        }
    }

    private func upcoming(_ summary: SubscriptionSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle(title: "Upcoming renewals")
                Picker("Upcoming renewals", selection: $days) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 160)
            }
            if !summary.overdue.isEmpty {
                Button { store.windowRequest = .waiting } label: {
                    Label("\(summary.overdue.count) overdue \(summary.overdue.count == 1 ? "payment needs" : "payments need") confirmation", systemImage: "clock.badge.exclamationmark")
                        .font(.callout)
                }.buttonStyle(.link).padding(.horizontal, 4)
            }
            if summary.renewals.isEmpty {
                Text("No renewals in the next \(days) days.").foregroundStyle(.secondary).padding(.vertical, 12)
            } else {
                Card {
                    ForEach(summary.renewals) { renewal in
                        Button {
                            if let rule = store.ledger.rules.first(where: { $0.id == renewal.ruleID }) {
                                onEdit(EditTarget(kind: .rule(rule)))
                            }
                        } label: {
                            MoneyRow(category: renewal.category, title: renewal.label,
                                     note: renewal.day == store.today ? "Today" : renewal.day.localDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                                     cents: renewal.cents)
                        }.buttonStyle(.plain).help("Edit \(renewal.label)")
                    }
                }
            }
        }
    }

    @ViewBuilder private func subscriptionList(_ title: String, rules: [Rule]) -> some View {
        if !rules.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: title, meta: "\(rules.count)")
                Card {
                    ForEach(rules) { rule in
                        HStack(spacing: 2) {
                            Button { onEdit(EditTarget(kind: .rule(rule))) } label: {
                                MoneyRow(category: rule.category, title: rule.label, tag: rule.active ? nil : "paused",
                                         note: rule.cadence.name + " · " + (rule.active ? "next " : "was due ")
                                            + rule.next.localDate.formatted(.dateTime.month(.abbreviated).day()),
                                         cents: rule.cents, rightNote: "per \(rule.cadence.unit)", dimmed: !rule.active)
                            }.buttonStyle(.plain).help("Edit \(rule.label)")
                            Menu {
                                Button("Edit…") { onEdit(EditTarget(kind: .rule(rule))) }
                                Button(rule.active ? "Pause Tracking" : "Resume Tracking") { store.setActive(rule.id, !rule.active) }
                                Button("Remove from Subscriptions") { store.setSubscription(rule.id, false) }
                                Divider()
                                Button("Stop Tracking…", role: .destructive) { stopping = rule }
                            } label: {
                                Image(systemName: "ellipsis").foregroundStyle(.secondary)
                            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                                .accessibilityLabel("Manage \(rule.label)").padding(.trailing, 8)
                        }
                    }
                }
            }
        }
    }

    private var reminders: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Remind me before renewals", isOn: $store.subscriptionReminders)
                    .toggleStyle(.switch)
                Text("At 10 AM the day before the next charge, on this Mac. Pausing tracking stops planned charges and reminders in Pocket; manage the subscription with its provider.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let message = store.reminderMessage {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
            }.padding(12)
        }
    }
}
