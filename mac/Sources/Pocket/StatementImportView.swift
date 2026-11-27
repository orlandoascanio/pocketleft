import AppKit
import PocketCore
import SwiftUI
import UniformTypeIdentifiers

/// A statement file someone chose, read and ready to preview.
struct StatementFile: Identifiable {
    let id = UUID()
    let name: String
    let text: String

    /// Reads a CSV the way banks save them: UTF-8 usually, older Windows encodings sometimes.
    static func read(_ url: URL) throws -> StatementFile {
        let data = try Data(contentsOf: url)
        guard data.count <= 10_000_000 else { throw CocoaError(.fileReadTooLarge) }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252)
                ?? String(data: data, encoding: .isoLatin1) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        return StatementFile(name: url.lastPathComponent, text: text)
    }

    /// Asks for a statement CSV. nil when canceled.
    @MainActor static func choose() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .tabSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a CSV statement exported from your bank or card."
        panel.prompt = "Preview"
        return panel.runModal() == .OK ? panel.url : nil
    }
}

/// Preview a statement, uncheck what's already recorded, then add the rest in one step that can be undone.
struct StatementImportSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let file: StatementFile
    var onDone: (String) -> Void

    @State private var dayFirst: Bool?
    @State private var flipSigns = false
    @State private var preview: StatementPreview?
    @State private var failure: String?
    @State private var excluded: Set<Int> = []
    @State private var error: String?

    private static let localeDayFirst: Bool = {
        let pattern = DateFormatter.dateFormat(fromTemplate: "Md", options: 0, locale: .current) ?? "M/d"
        return (pattern.firstIndex(of: "d") ?? pattern.endIndex) < (pattern.firstIndex(of: "M") ?? pattern.endIndex)
    }()

    private var chosen: [StatementRow] { preview?.rows.filter { !excluded.contains($0.line) } ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import Statement").font(.title2.weight(.semibold))
                Text(subtitle).foregroundStyle(.secondary)
            }
            if let failure {
                Text(failure).foregroundStyle(Palette.negative).fixedSize(horizontal: false, vertical: true)
                Spacer()
                HStack { Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.defaultAction) }
            } else if let preview {
                options(preview)
                rows(preview)
                footer(preview)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(width: 660, height: 600)
        .onAppear(perform: reload)
        .onChange(of: dayFirst) { reload() }
        .onChange(of: flipSigns) { reload() }
    }

    private var subtitle: String {
        guard let preview, let first = preview.firstDay, let last = preview.lastDay else { return file.name }
        let range = first == last ? short(first) : "\(short(first)) – \(short(last))"
        return "\(file.name) · \(preview.rows.count) \(preview.rows.count == 1 ? "row" : "rows") · \(range)"
    }

    private func short(_ day: Day) -> String { day.localDate.formatted(.dateTime.month(.abbreviated).day().year()) }

    private func reload() {
        do {
            let next = try StatementImport.preview(file.text, ledger: store.ledger, today: store.today, dayFirst: dayFirst,
                                                   localeDayFirst: Self.localeDayFirst, flipSigns: flipSigns)
            preview = next
            excluded = Set(next.rows.filter { !$0.includedByDefault }.map(\.line))
            failure = next.rows.isEmpty ? "Pocket couldn't find any entries with a date and an amount in this file." : nil
        } catch {
            failure = error.localizedDescription
        }
    }

    @ViewBuilder private func options(_ preview: StatementPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if preview.ambiguousDates || dayFirst != nil {
                Picker("Dates in this file", selection: Binding(get: { dayFirst ?? preview.dayFirst }, set: { dayFirst = $0 })) {
                    Text("Month first (11/3)").tag(false)
                    Text("Day first (3/11)").tag(true)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            Toggle("Spending is listed as positive amounts", isOn: $flipSigns)
                .toggleStyle(.checkbox)
                .help("Card statements often list purchases as positive numbers. Turn this on so they count as spending.")
            let spending = preview.rows.filter { $0.cents < 0 }.count
            if !flipSigns, preview.columns.amount != nil, preview.columns.debit == nil, preview.columns.credit == nil,
               preview.rows.count >= 3, spending * 4 < preview.rows.count {
                Text("Most amounts here are money in. If this is a card statement, purchases are probably listed as positive.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            let recorded = preview.rows.filter { if case .recorded = $0.duplicate { return true } else { return false } }.count
            if recorded > 0 {
                Label("\(recorded) \(recorded == 1 ? "row looks" : "rows look") like \(recorded == 1 ? "an entry" : "entries") already in Pocket, so \(recorded == 1 ? "it’s" : "they’re") unchecked.",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout)
            }
        }
    }

    private func rows(_ preview: StatementPreview) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button("Select All") { excluded = [] }
                Button("Select None") { excluded = Set(preview.rows.map(\.line)) }
                Spacer()
                if !preview.skipped.isEmpty {
                    Text("\(preview.skipped.count) \(preview.skipped.count == 1 ? "line" : "lines") skipped")
                        .font(.callout).foregroundStyle(.secondary)
                        .help(preview.skipped.prefix(12).map { "Line \($0.line): \($0.reason)" }.joined(separator: "\n"))
                }
            }
            .buttonStyle(.link)
            .padding(.bottom, 6)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(preview.rows) { row in
                        StatementRowView(row: row, money: store.money, included: Binding(
                            get: { !excluded.contains(row.line) },
                            set: { if $0 { excluded.remove(row.line) } else { excluded.insert(row.line) } }))
                        Divider()
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
        }
    }

    private func footer(_ preview: StatementPreview) -> some View {
        let picked = chosen
        let spent = picked.filter { $0.cents < 0 }.reduce(0) { $0 - $1.cents }
        let into = picked.filter { $0.cents > 0 }.reduce(0) { $0 + $1.cents }
        var parts: [String] = []
        if spent > 0 { parts.append("\(store.money.string(spent)) spent") }
        if into > 0 { parts.append("\(store.money.string(into)) in") }
        return VStack(alignment: .leading, spacing: 8) {
            if let error { Text(error).foregroundStyle(Palette.negative) }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(parts.isEmpty ? "Nothing selected" : parts.joined(separator: " · ")).monospacedDigit()
                    Text("You can undo the whole import from Settings.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(picked.count == 1 ? "Import 1 Entry" : "Import \(picked.count) Entries") {
                    guard store.importStatement(picked, fileName: file.name) != nil else {
                        error = "Couldn't import. Your saved data is unchanged."
                        return
                    }
                    onDone("Imported \(picked.count) \(picked.count == 1 ? "entry" : "entries") from \(file.name).")
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(picked.isEmpty)
            }
        }
    }
}

private struct StatementRowView: View {
    let row: StatementRow
    let money: Money
    @Binding var included: Bool

    private var note: String? {
        switch row.duplicate {
        case .recorded(let entry):
            "Looks like “\(entry.label)” on \(entry.day.localDate.formatted(.dateTime.month(.abbreviated).day())), already in Pocket"
        case .repeated(let line): "Same as line \(line). Keep both if you were charged twice."
        case nil: nil
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Toggle(isOn: $included) { EmptyView() }
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityLabel("Import \(row.label)")
            Text(row.day.localDate.formatted(.dateTime.month(.abbreviated).day()))
                .monospacedDigit().foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.label).lineLimit(1).truncationMode(.tail)
                if let note {
                    Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Text(money.string(row.cents, signed: true))
                .monospacedDigit()
                .foregroundStyle(row.cents > 0 ? Palette.accent : Color.primary)
        }
        .opacity(included ? 1 : 0.55)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { included.toggle() }
    }
}
