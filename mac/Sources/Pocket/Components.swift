import AppKit
import PocketCore
import SwiftUI

extension Categories {
    /// One hue per category, shared with Pocket Sync and the web app. Red stays reserved for "below zero".
    static func tint(_ id: String?, cents: Cents) -> Color {
        let color: NSColor
        switch id {
        case "games": color = .systemPurple
        case "subscriptions": color = .systemBlue
        case "bills", "fun": color = .systemOrange
        case "apps": color = .systemIndigo
        case "food": color = .systemBrown
        case "shopping": color = .systemPink
        case "transport": color = .systemTeal
        case "pay", "gift", "refund", "start", "otherin": return Palette.accent
        default: return cents > 0 ? Palette.accent : Color.secondary
        }
        // Slightly deeper in light mode so the glyph keeps its contrast on the tinted tile.
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? color : color.blended(withFraction: 0.22, of: .black) ?? color
        })
    }
}

/// A category glyph on a tile of its own hue.
struct CategoryIcon: View {
    var category: String?
    var cents: Cents
    var size: CGFloat = 32
    /// Overrides the category's glyph (clock for one-time plans, repeat for rules).
    var symbol: String? = nil
    /// Shown in gray when no category is set, instead of the generic in/out arrow.
    var placeholder: String? = nil

    var body: some View {
        let empty = category == nil && placeholder != nil
        let tint = empty ? Color.secondary : Categories.tint(category, cents: cents)
        Image(systemName: empty ? placeholder! : symbol ?? Categories.symbol(category, cents: cents))
            .font(.system(size: size * 0.44, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(tint.opacity(empty ? 0.08 : 0.14)))
            .accessibilityHidden(true)
    }
}

/// A row in History, Coming up or Repeating.
struct MoneyRow: View {
    var category: String?
    var symbol: String? = nil
    var title: String
    var tag: String? = nil
    var note: String
    var cents: Cents
    var rightNote: String? = nil
    var rightNegative = false
    var selected = false
    var dimmed = false
    var noteDisclosure = false
    @EnvironmentObject var store: Store
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: category, cents: cents, symbol: symbol)
                .opacity(dimmed ? 0.55 : 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).lineLimit(1)
                    if let tag {
                        Text(tag).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.line))
                    }
                }
                if !note.isEmpty {
                    HStack(spacing: 4) {
                        Text(note).lineLimit(1)
                        if noteDisclosure {
                            Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                                .accessibilityHidden(true)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(noteDisclosure ? Palette.accent : Color.secondary)
                }
            }
            .opacity(dimmed ? 0.55 : 1)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(store.money.string(cents, signed: true))
                    .fontWeight(.medium).monospacedDigit()
                    .foregroundStyle(cents > 0 ? Palette.accent : Color.primary)
                if let rightNote {
                    Text(rightNote).font(.caption).monospacedDigit()
                        .foregroundStyle(rightNegative ? Palette.negative : .secondary)
                }
            }
            .opacity(dimmed ? 0.55 : 1)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? Palette.accent.opacity(0.14) : hovering ? Color.primary.opacity(0.05) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

/// A rounded card like the web app's.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(6)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line))
    }
}

struct SectionTitle: View {
    var title: String
    var meta: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.display(17, .semibold))
            Spacer()
            if let meta { Text(meta).font(.callout).foregroundStyle(.secondary).monospacedDigit() }
        }
        .padding(.horizontal, 4)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A selectable capsule (frequency, category).
struct Chip: View {
    var title: String
    var symbol: String? = nil
    var on: Bool
    var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)) }
                Text(title)
            }
            .font(.callout)
            .padding(.horizontal, 11).padding(.vertical, 5)
            .foregroundStyle(on ? Palette.bg : Color.primary)
            .background(on ? Color.primary : Palette.chip, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: on)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The row of quick-add buttons.
struct QuickBar: View {
    @EnvironmentObject var store: Store
    var onAsk: (Preset) -> Void
    @StateObject private var scroll = PresetScrollState()

    var body: some View {
        HStack(spacing: 4) {
            PresetScroller(state: scroll, presets: store.ledger.presets, money: store.money, onUse: use)
            .frame(height: 34)
            if scroll.overflows {
                Button { scroll.page(-1) } label: {
                    Image(systemName: "chevron.left").foregroundStyle(Color.secondary.opacity(scroll.canScrollBack ? 1 : 0.35))
                }
                    .buttonStyle(RoundButtonStyle())
                    .disabled(!scroll.canScrollBack)
                    .help("Previous quick-add buttons")
                    .accessibilityLabel("Previous quick-add buttons")
                Button { scroll.page(1) } label: {
                    Image(systemName: "chevron.right").foregroundStyle(Color.secondary.opacity(scroll.canScrollForward ? 1 : 0.35))
                }
                    .buttonStyle(RoundButtonStyle())
                    .disabled(!scroll.canScrollForward)
                    .help("Next quick-add buttons")
                    .accessibilityLabel("Next quick-add buttons")
            }
        }
    }

    private func use(_ p: Preset) {
        guard !scroll.suppressActivation else { return }
        guard let c = p.cents else { onAsk(p); return }
        store.addEntry(cents: p.sign * c, label: p.label, day: store.today, category: p.category)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// A failed write is visible where the user is working, until a write succeeds.
struct SaveFailureView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        if let error = store.saveError {
            VStack(alignment: .leading, spacing: 4) {
                Label(store.loadError == nil ? "Your last change wasn't saved" : "Your saved data couldn't be opened", systemImage: "exclamationmark.triangle")
                    .font(.callout.weight(.semibold))
                Text(store.loadError == nil ? "Your saved balance is unchanged. Try the action again."
                     : "Your file is preserved. Restore a backup in Settings, or repair the file and try opening it again.")
                    .font(.caption)
                Text(error).font(.caption).textSelection(.enabled)
                if store.loadError != nil {
                    HStack {
                        Button("Show Data in Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.fileURL]) }
                        Button("Try Again") { store.retryLoadingData() }
                    }
                }
            }
            .foregroundStyle(Palette.negative)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain)
        }
    }
}

/// The one-time suggestion to tell someone about Pocket. "Not now" hides it for good;
/// Share Pocket… in the menus stays available either way.
struct SharePromptView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        if store.showSharePrompt {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label("Know someone who'd like Pocket?", systemImage: "heart").font(.callout).lineLimit(2)
                Spacer(minLength: 0)
                Button("Not now") { store.dismissSharePrompt() }.buttonStyle(.link).foregroundStyle(.secondary).fixedSize()
                Button("Share…") { store.shareFromPrompt() }.buttonStyle(.link).fixedSize()
            }
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityElement(children: .contain)
        }
    }
}

/// "Added −$6.50 · Coffee", with entry actions.
struct EntryReceiptView: View {
    @EnvironmentObject var store: Store
    @State private var undoError: String?
    var onEdit: (WindowRequest) -> Void
    var body: some View {
        if let receipt = store.receipt {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Label(receipt.text, systemImage: "checkmark.circle")
                        .font(.callout).lineLimit(2)
                    Spacer(minLength: 0)
                    if case .editEntry(let id) = receipt.target,
                       let entry = store.ledger.entries.first(where: { $0.id == id }) {
                        Button("Undo") { undoError = store.undoEntryReceipt(id) }
                            .buttonStyle(.link)
                            .fixedSize()
                            .help("Undo the entry just added")
                        if store.canSaveAsPreset(entry) {
                            Button("Save as Button") { store.saveAsPreset(id) }
                                .buttonStyle(.link)
                                .fixedSize()
                                .help("Make a quick-add button for “\(entry.label)”, so next time it's one click or ⌘-number")
                        }
                    }
                    Button("Edit") { onEdit(receipt.target) }
                        .buttonStyle(.link)
                        .fixedSize()
                        .accessibilityLabel(receipt.target == .section(.settings) ? "Edit quick-add buttons" : "Edit the entry just saved")
                }
                if let undoError {
                    Text(undoError).font(.caption).foregroundStyle(Palette.negative)
                }
            }
            .foregroundStyle(Palette.accent)
            .onChange(of: receipt.target) { undoError = nil }
        }
    }
}

/// Shrinks a little while pressed. Feedback lands on mouse-down, not on release.
struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0), value: configuration.isPressed)
    }
}

/// Round icon button for chrome: the fill appears on hover and deepens on press, the way toolbar items do.
struct RoundButtonStyle: ButtonStyle {
    var size: CGFloat = 26
    func makeBody(configuration: Configuration) -> some View { RoundLabel(configuration: configuration, size: size) }
    private struct RoundLabel: View {
        let configuration: Configuration
        let size: CGFloat
        @State private var hover = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        var body: some View {
            configuration.label
                .frame(width: size, height: size)
                .background(Circle().fill(Color.primary.opacity(configuration.isPressed ? 0.14 : hover ? 0.07 : 0)))
                .contentShape(Circle())
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
                .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0), value: configuration.isPressed)
                .onHover { hover = $0 }
        }
    }
}

/// The amount, typed large. SwiftUI's plain TextField can clip its field editor when a large-font
/// value is cleared while focused, so this keeps the native control and its editor at the same size.
struct AmountField: NSViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var size: CGFloat = 28
    var placeholder = "0.00"
    @Environment(\.isEnabled) private var enabled
    let onSubmit: () -> Void

    final class Control: NSTextField {
        var height: CGFloat = 40
        override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: height) }
    }

    static func font(_ size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .semibold)
        let rounded = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        let tabular = rounded.addingAttributes([.featureSettings: [[
            NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
            NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector,
        ]]])
        return NSFont(descriptor: tabular, size: size) ?? base
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> Control {
        let field = Control()
        field.height = (size * 1.4).rounded()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .exterior
        field.font = Self.font(size)
        field.textColor = .labelColor
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [
            .font: field.font!, .foregroundColor: NSColor.secondaryLabelColor
        ])
        field.setAccessibilityLabel("Amount")
        field.setAccessibilityHelp("Enter an amount with up to two decimal places. Return moves to the description or saves the entry.")
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: Control, context: Context) {
        context.coordinator.parent = self
        field.isEnabled = enabled
        if field.stringValue != text {
            field.stringValue = text
            if let editor = field.currentEditor() as? NSTextView {
                editor.string = text
                editor.font = field.font
                editor.setSelectedRange(NSRange(location: text.utf16.count, length: 0))
            }
        }
        if focused && enabled && field.currentEditor() == nil {
            DispatchQueue.main.async { [weak field] in
                guard let field, context.coordinator.parent.focused, context.coordinator.parent.enabled,
                      field.currentEditor() == nil else { return }
                field.window?.makeFirstResponder(field)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AmountField
        init(_ parent: AmountField) { self.parent = parent }
        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSTextField { parent.text = field.stringValue }
        }
        func controlTextDidBeginEditing(_ notification: Notification) { parent.focused = true }
        func controlTextDidEndEditing(_ notification: Notification) { parent.focused = false }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy command: Selector) -> Bool {
            guard command == #selector(NSResponder.insertNewline(_:)) else { return false }
            parent.onSubmit()
            return true
        }
    }
}

/// Amount-first entry, shared by the menu and the window: direction, a large amount, then what it was for.
struct Composer: View {
    @EnvironmentObject var store: Store
    @ObservedObject var state: EditorState
    var amountSize: CGFloat = 28
    var showSaveTitle = false
    var onMore: (() -> Void)? = nil
    @State private var amountFocused = false
    @FocusState private var labelFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canSave: Bool { Money.parse(state.amount) != nil }
    private var categories: [PocketCore.Category] { state.spent ? Categories.spending : Categories.income }
    private var spring: Animation? { reduceMotion ? nil : .spring(duration: 0.25, bounce: 0) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { withAnimation(spring) { state.spent.toggle() } } label: {
                    Image(systemName: state.spent ? "minus" : "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(state.spent ? Color.primary : Color.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(state.spent ? Color.primary.opacity(0.08) : Palette.accent))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(PressStyle())
                .help(state.spent ? "Money out. Click, or type +, for money in." : "Money in. Click, or type -, for money out.")
                .accessibilityLabel(state.spent ? "Spent" : "Got money")
                .accessibilityHint("Switches between money out and money in")
                Text(store.money.symbol)
                    .font(.system(size: amountSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(state.spent ? AnyShapeStyle(.secondary) : AnyShapeStyle(Palette.accent))
                AmountField(text: $state.amount, focused: $amountFocused, size: amountSize, placeholder: store.money.placeholder) {
                    if state.label.trimmed.isEmpty { labelFocused = true } else { save() }
                }
                .frame(height: (amountSize * 1.4).rounded())
                if canSave && !showSaveTitle {
                    Button(action: save) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: amountSize * 0.93))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.white, Palette.accent)
                    }
                    .buttonStyle(PressStyle())
                    .keyboardShortcut(.defaultAction)
                    .help(state.spent ? "Add spending · Return" : "Add money in · Return")
                    .accessibilityLabel(state.spent ? "Add spending" : "Add money in")
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .animation(spring, value: canSave)
            Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 44)
            HStack(spacing: 8) {
                categoryMenu
                TextField(state.spent ? "What was it for?" : "Where's it from?", text: $state.label)
                    .textFieldStyle(.plain)
                    .focused($labelFocused)
                    .onSubmit(save)
                    .accessibilityLabel("Description")
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            if showSaveTitle {
                Button(state.spent ? "Add expense" : "Add money in", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                    .padding(.horizontal, 12).padding(.bottom, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let onMore {
                HStack {
                    Spacer()
                    Button(action: onMore) {
                        Label("Date & repeat", systemImage: "calendar")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Open the entry form to choose a date, category or repeat schedule")
                    .accessibilityHint("Opens the full entry form and keeps what you have typed")
                }
                .padding(.horizontal, 12).padding(.bottom, 9)
            }
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line))
        .animation(spring, value: state.spent)
        .onChange(of: state.focusAmount) { _, _ in amountFocused = true }
        .onAppear { state.store = store }
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(categories) { c in
                Button { state.category = c.id; state.categoryTouched = true } label: { Label(c.name, systemImage: c.symbol) }
            }
            Divider()
            Button("No category") { state.category = nil; state.categoryTouched = true }
            if let onMore {
                Divider()
                Button("Date, repeat and more…", action: onMore)
            }
        } label: {
            CategoryIcon(category: state.category, cents: state.spent ? -1 : 1, size: 26, placeholder: "tag")
        }
        .menuStyle(.button)
        .buttonStyle(PressStyle())
        .menuIndicator(.hidden)
        .fixedSize()
        .help(state.category.map(Categories.name) ?? "Category")
        .accessibilityLabel("Category, " + (state.category.map(Categories.name) ?? "none"))
    }

    private func save() {
        state.date = Date()
        if state.label.trimmed.isEmpty && Money.parse(state.amount) != nil {
            labelFocused = true
            state.error = state.spent ? "Say what it was for." : "Say where it's from."
            return
        }
        state.save()
    }
}
