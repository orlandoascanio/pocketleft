import PocketCore
import SwiftUI

struct SubscriptionEditor: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var state: EditorState
    let existing: Rule?
    @State private var showOptions = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "repeat")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 36, height: 36)
                    .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                Text(existing == nil ? "New Subscription" : "Edit Subscription")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
            }
            field("Subscription name") {
                TextField("Subscription name", text: $state.label, prompt: Text("e.g. Netflix"))
                    .labelsHidden().textFieldStyle(.roundedBorder).controlSize(.large)
                    .focused($nameFocused)
            }
            Card {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 24) {
                        field("Price per renewal") {
                            HStack(spacing: 6) {
                                Text(store.money.symbol).foregroundStyle(.secondary)
                                TextField("Price per renewal", text: $state.amount, prompt: Text(store.money.placeholder))
                                    .labelsHidden().textFieldStyle(.roundedBorder).controlSize(.large)
                                    .monospacedDigit()
                                Text(store.ledger.currency).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        field("Billing cycle") {
                            Picker("Billing cycle", selection: $state.frequency) {
                                ForEach(Frequency.allCases.filter { $0.cadence != nil }) { frequency in
                                    Text(frequency.cadence?.name ?? frequency.name).tag(frequency)
                                }
                            }.labelsHidden().pickerStyle(.menu).controlSize(.large)
                        }
                    }
                    Divider()
                    HStack {
                        Text("Next renewal").fontWeight(.medium)
                        Spacer()
                        DatePicker("Next renewal", selection: $state.date, displayedComponents: .date)
                            .labelsHidden().controlSize(.large)
                    }
                }
                .padding(8)
            }
            DisclosureGroup("More Options", isExpanded: $showOptions) {
                options.padding(.top, 10)
            }
            SaveFailureView()
            if let error = state.error {
                Text(error).font(.callout).foregroundStyle(Palette.negative)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            savingNotice
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .buttonStyle(.bordered).keyboardShortcut(.cancelAction)
                Button(existing == nil ? "Add Subscription" : "Save Changes") {
                    if state.save() { dismiss() }
                }
                .buttonStyle(.borderedProminent).tint(Palette.accent).keyboardShortcut(.defaultAction)
                .disabled(state.label.trimmed.isEmpty || Money.parse(state.amount) == nil)
            }
            .controlSize(.large)
        }
        .padding(22)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .presentationBackground(Palette.bg)
        .background { Palette.bg.ignoresSafeArea() }
        .tint(Palette.accent)
        .onAppear {
            state.store = store
            state.startSubscription(existing)
            showOptions = !state.times.isEmpty || (existing != nil && state.category != "subscriptions")
            nameFocused = existing == nil
        }
    }

    @ViewBuilder private var savingNotice: some View {
        let charges = state.subscriptionChargesOnSave
        if let first = charges.first {
            let price = store.money.string(abs(first.cents))
            Label {
                if charges.count > 1 {
                    Text("Saving will record \(charges.count) payments of \(price) each in History.")
                } else if first.day == store.today {
                    Text("Saving will record \(price) in History today.")
                } else {
                    Text("Saving will record \(price) in History for \(first.day.localDate.formatted(.dateTime.month(.abbreviated).day().year())).")
                }
            } icon: {
                Image(systemName: "info.circle").foregroundStyle(Palette.accent)
            }
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var options: some View {
        HStack(alignment: .top, spacing: 24) {
            field("Category") {
                Picker("Category", selection: $state.category) {
                    Text("None").tag(String?.none)
                    if let category = state.category,
                       !Categories.spending.contains(where: { $0.id == category }) {
                        Text(category).tag(Optional(category))
                    }
                    Divider()
                    ForEach(Categories.spending) { Label($0.name, systemImage: $0.symbol).tag(Optional($0.id)) }
                }.labelsHidden().pickerStyle(.menu)
            }
            field("Renewals remaining") {
                TextField("Renewals remaining", text: $state.times, prompt: Text("No end"))
                    .labelsHidden().textFieldStyle(.roundedBorder).monospacedDigit()
            }
        }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.callout.weight(.medium)).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
