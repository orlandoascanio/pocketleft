import PocketCore
import SwiftUI

enum RenewalReminderTarget: Hashable, Identifiable {
    case defaults
    case subscription(UUID)

    var id: Self { self }
}

struct RenewalReminderEditor: View {
    private enum Method: String, Identifiable {
        case days = "Days before"
        case date = "Specific date"
        case savedHours = "Hours before"

        var id: Self { self }
    }

    private struct Draft: Identifiable {
        let id = UUID()
        var method = Method.days
        var days = String(RenewalReminderTiming().amount)
        var time = Self.time(at: 600, on: .now)
        var exact = Date()
        var savedHours: RenewalReminderTiming?

        init(days: Int) { self.days = String(days) }

        init(_ reminder: RenewalReminder) {
            switch reminder {
            case .relative(let timing):
                if timing.unit == .hours {
                    method = .savedHours
                    savedHours = timing
                } else {
                    days = String(timing.amount)
                    time = Self.time(at: timing.minuteOfDay, on: .now)
                }
            case let .exact(day, minuteOfDay, _):
                method = .date
                exact = Self.time(at: minuteOfDay, on: day.localDate)
            }
        }

        func reminder(for renewal: Day?, now: Date) -> RenewalReminder? {
            switch method {
            case .days:
                guard let count = Int(days.trimmingCharacters(in: .whitespaces)) else { return nil }
                let timing = RenewalReminderTiming(amount: count, minuteOfDay: Self.minute(of: time))
                return timing.isValid ? .relative(timing) : nil
            case .date:
                guard let renewal else { return nil }
                let reminder = RenewalReminder.exact(day: Day(exact), minuteOfDay: Self.minute(of: exact), renewal: renewal)
                guard let fireDate = reminder.date(for: renewal), fireDate > now else { return nil }
                return reminder
            case .savedHours:
                return savedHours.map(RenewalReminder.relative)
            }
        }

        static func time(at minute: Int, on date: Date) -> Date {
            Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: date) ?? date
        }

        private static func minute(of date: Date) -> Int {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            return (parts.hour ?? 10) * 60 + (parts.minute ?? 0)
        }
    }

    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [Draft]
    @State private var reminderRowsHeight: CGFloat = 1
    @State private var removingReminder: UUID?
    private let target: RenewalReminderTarget

    init(target: RenewalReminderTarget, reminders: [RenewalReminder]) {
        self.target = target
        _drafts = State(initialValue: reminders.map(Draft.init))
    }

    private var rule: Rule? {
        guard case let .subscription(id) = target else { return nil }
        return store.ledger.liveRules.first { $0.id == id && $0.active && $0.isSubscription }
    }

    private var canUseExactDate: Bool { rule.map { $0.next > store.today } ?? false }
    private var canRemove: Bool { target != .defaults || drafts.count > 1 }

    var body: some View {
        let rule = rule
        let reminders = drafts.compactMap { $0.reminder(for: rule?.next, now: .now) }
        let dates = rule.map { rule in reminders.compactMap { $0.date(for: rule.next) } } ?? []
        let duplicates = Set(reminders).count < reminders.count || Set(dates).count < dates.count
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 34, height: 34)
                    .background(Palette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.map { "Reminders for \($0.label)" } ?? "Default renewal reminders")
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    if let rule {
                        Text("Next renewal \(rule.next.localDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            if !store.subscriptionReminders {
                Text("Turn on renewal reminders in Subscriptions to receive these.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if drafts.isEmpty {
                Text("No reminders").foregroundStyle(.secondary)
            } else {
                ScrollView {
                    reminderRows.onGeometryChange(for: CGFloat.self, of: { $0.size.height }) {
                        if $0 > 0 { reminderRowsHeight = $0 }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(reminderRowsHeight, 246))
            }
            Button(action: addReminder) {
                Label("Add Reminder", systemImage: "plus.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Palette.accent.opacity(0.10), in: Capsule())
            }.buttonStyle(.plain)
            if duplicates {
                Text("Give each reminder a different time.").font(.callout).foregroundStyle(Palette.negative)
            }
            Divider()
            HStack(spacing: 8) {
                if let rule, store.renewalReminders.subscriptions[rule.id] != nil {
                    Button("Use Default", systemImage: "arrow.uturn.backward") {
                        store.setRenewalReminders(nil, for: rule.id)
                        dismiss()
                    }
                    .buttonStyle(.borderless)
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    store.setRenewalReminders(reminders, for: rule?.id)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(reminders.count != drafts.count || duplicates || (target != .defaults && rule == nil))
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .presentationBackground(Palette.bg)
        .background { Palette.bg.ignoresSafeArea() }
        .tint(Palette.accent)
        .alert("Remove this reminder?", isPresented: Binding(
            get: { removingReminder != nil }, set: { if !$0 { removingReminder = nil } }
        ), presenting: removingReminder) { id in
            Button("Cancel", role: .cancel) {}
            Button("Remove Reminder", role: .destructive) { drafts.removeAll { $0.id == id } }
        } message: { _ in
            Text("The notification will be removed when you save.")
        }
    }

    private var reminderRows: some View {
        VStack(spacing: 8) {
            ForEach($drafts) { $draft in
                reminderRow($draft)
            }
        }
        .padding(2)
    }

    private func reminderRow(_ draft: Binding<Draft>) -> some View {
        let showMethod = canUseExactDate || draft.wrappedValue.savedHours != nil || draft.wrappedValue.method == .date
        let time = draft.wrappedValue.reminder(for: rule?.next, now: .now)
        return VStack(alignment: .leading, spacing: 6) {
            if showMethod || canRemove {
                HStack {
                    if showMethod {
                        Picker("Reminder type", selection: draft.method) {
                            Text(Method.days.rawValue).tag(Method.days)
                            if canUseExactDate || draft.wrappedValue.method == .date {
                                Text(Method.date.rawValue).tag(Method.date)
                            }
                            if draft.wrappedValue.savedHours != nil {
                                Text(Method.savedHours.rawValue).tag(Method.savedHours)
                            }
                        }.labelsHidden().fixedSize()
                    }
                    Spacer()
                    if canRemove {
                        Button(role: .destructive) {
                            removingReminder = draft.wrappedValue.id
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Palette.negative)
                        }
                        .buttonStyle(RoundButtonStyle(size: 30))
                        .accessibilityLabel("Remove reminder…")
                        .help("Remove this reminder")
                    }
                }
            }
            switch draft.wrappedValue.method {
            case .days:
                HStack {
                    TextField("Days before renewal", text: draft.days)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 48)
                    Text("days before")
                    Spacer()
                    DatePicker("At", selection: draft.time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.field)
                }
                if time == nil {
                    Text("Enter 1 to 365 days.").font(.caption).foregroundStyle(Palette.negative)
                }
            case .date:
                DatePicker("Date and time", selection: draft.exact, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.field)
                Text(time == nil
                     ? "Choose a future time before the next renewal date."
                     : "One-time reminder for this renewal.")
                    .font(.caption).foregroundStyle(.secondary)
            case .savedHours:
                if let timing = draft.wrappedValue.savedHours {
                    Text("\(timing.amount) hours before renewal")
                }
            }
            if draft.wrappedValue.method != .date, let rule,
               let date = time?.date(for: rule.next), date > Date() {
                Label(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()),
                      systemImage: "bell")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Palette.chip.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line))
        .onChange(of: draft.wrappedValue.method) { _, current in
            let now = Date()
            guard current == .date, let rule,
                  draft.wrappedValue.exact <= now || Day(draft.wrappedValue.exact) >= rule.next else { return }
            let tomorrow = store.today.adding(days: 1)
            draft.wrappedValue.exact = tomorrow < rule.next
                ? Draft.time(at: 600, on: tomorrow.localDate)
                : min(now.addingTimeInterval(3_600), Draft.time(at: 1_439, on: now))
        }
    }

    private func addReminder() {
        let used = Set(drafts.filter { $0.method == .days }.compactMap { Int($0.days) })
        let defaultDays = RenewalReminderTiming().amount
        let next = (defaultDays...365).first { !used.contains($0) } ?? 1
        drafts.append(Draft(days: next))
    }
}
