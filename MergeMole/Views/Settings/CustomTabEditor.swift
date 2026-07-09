import SwiftUI

/// The add/edit sheet for a custom tab (Settings → Tabs): a name, a raw GitHub
/// search, and a list of query tips — each one qualifier with an **Add** button
/// that appends it, so a search can be composed without knowing the syntax. The
/// query is otherwise taken as written — power users keep the full search
/// language — with one guardrail applied on the wire (`is:pr`), noted under the
/// field so the behavior is never a surprise. Writes through `AppModel` on save.
struct CustomTabEditor: View {
    /// What the sheet is doing — drives the title, the primary button, and
    /// whether Delete is offered. `Identifiable` so it can drive `.sheet(item:)`.
    enum Mode: Identifiable {
        case create
        case edit(CustomTab)

        /// The tab being edited, or nil when creating a new one.
        var tab: CustomTab? {
            if case .edit(let tab) = self { return tab }
            return nil
        }

        var id: String { tab?.id.uuidString ?? "create" }
    }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    @State private var name: String
    @State private var query: String
    @State private var confirmingDelete = false

    init(mode: Mode) {
        self.mode = mode
        _name = State(initialValue: mode.tab?.name ?? "")
        _query = State(initialValue: mode.tab?.query ?? "")
    }

    /// One search qualifier the Add button appends to the query — building blocks,
    /// not complete searches, so they compose. Placeholders (`owner/name`) are for
    /// the user to edit after adding.
    private struct QueryTip {
        let label: String
        let snippet: String
    }

    private static let tips: [QueryTip] = [
        .init(label: "Open PRs only",     snippet: "is:open"),
        .init(label: "Needs your review", snippet: "review-requested:@me"),
        .init(label: "Created by you",    snippet: "author:@me"),
        .init(label: "One repository",    snippet: "repo:owner/name"),
        .init(label: "One organization",  snippet: "org:name"),
        .init(label: "With a label",      snippet: "label:urgent"),
        .init(label: "No drafts",         snippet: "draft:false"),
        .init(label: "No bots",           snippet: "-author:app/dependabot"),
    ]

    private static let searchDocsURL = URL(string: "https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/filtering-and-searching-issues-and-pull-requests")!

    private var isEditing: Bool { mode.tab != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.roomy) {
            header
            nameField
            searchField
            tipsCard
            footer
        }
        .padding(Layout.generous)
        .frame(width: 440)
        .background(Color.appBackground)
        .confirmationDialog("Delete this tab?", isPresented: $confirmingDelete) {
            Button("Delete Tab", role: .destructive) {
                if let tab = mode.tab { model.removeCustomTab(tab.id) }
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("“\(name)” and its saved search are removed from the panel.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Layout.tight) {
            Text(isEditing ? "Edit Tab" : "New Tab")
                .font(.headline)
                .foregroundStyle(.appText)
            Text("Show any GitHub pull-request search as a tab in the panel.")
                .font(.caption)
                .foregroundStyle(.appTextSecondary)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Layout.tight) {
            FieldLabel("Name", hint: "what the tab is called")
            TextField("", text: $name, prompt: Text("Release blockers"))
                .settingsField()
        }
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: Layout.tight) {
            FieldLabel("Search", hint: "which pull requests it shows")
            TextField("", text: $query, prompt: Text("is:open label:release-blocker"))
                .settingsField()
                .font(.body.monospaced())
                .onSubmit { if canSave { save() } }
            searchCaption
        }
    }

    /// The line under the Search field. While the query is empty it teaches the
    /// one rule that trips people up — filters AND together — and once there's a
    /// query it becomes a live plain-English readout of what the tab will show,
    /// which teaches the same rule by example ("…, and …, and …").
    @ViewBuilder private var searchCaption: some View {
        if let sentence = QuerySummary.sentence(for: query) {
            Text(sentence)
                .font(.caption)
                .foregroundStyle(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Stack any GitHub search filters. They combine as AND — a PR appears only when every filter matches.")
                .font(.caption)
                .foregroundStyle(.appTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The composable qualifiers, each appended by its Add button (disabled once
    /// it's already in the search).
    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: Layout.base) {
            SectionHeader(title: "Query tips")

            ForEach(Self.tips, id: \.snippet) { tip in
                HStack(spacing: Layout.base) {
                    Text(tip.label)
                        .font(.callout)
                        .foregroundStyle(.appText)
                    Spacer(minLength: Layout.base)
                    Text(tip.snippet)
                        .font(.caption.monospaced())
                        .foregroundStyle(.appTextSecondary)
                        .lineLimit(1)
                    Button("Add") { append(tip.snippet) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(query.contains(tip.snippet))
                }
            }
        }
        .cardSurface()
    }

    private var footer: some View {
        HStack(spacing: Layout.base) {
            if isEditing {
                Button("Delete Tab…", role: .destructive) { confirmingDelete = true }
                    .buttonStyle(.borderless)
                    .tint(.appRed)
            }
            Link("Search syntax docs", destination: Self.searchDocsURL)
                .font(.callout)
                .tint(.appAccent)
            Spacer(minLength: Layout.base)
            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
                .tint(.appRed)
                .keyboardShortcut(.cancelAction)
            Button(isEditing ? "Save" : "Add Tab") { save() }
                .buttonStyle(.borderedProminent)
                .tint(.appAccent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
        }
    }

    /// Append a qualifier to the search, single-spaced. Placeholders stay for the
    /// user to edit (`repo:owner/name`), matching how the tips read.
    private func append(_ snippet: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        query = trimmed.isEmpty ? snippet : "\(trimmed) \(snippet)"
    }

    private func save() {
        switch mode {
        case .create:
            model.addCustomTab(name: name, query: query)
        case .edit(let tab):
            model.updateCustomTab(tab.id, name: name, query: query)
        }
        dismiss()
    }
}

/// Translates a GitHub search into the plain-English sentence shown under the
/// Search field — "This tab shows pull requests that are open, and you opened."
/// Joining every filter with "and" is the point: qualifiers AND together, and the
/// sentence makes a contradictory query (say, `author:@me review-requested:@me`)
/// read as obviously impossible. Unknown qualifiers fall back to "match “…”", so
/// the sentence never blocks syntax we don't know.
private enum QuerySummary {

    /// The sentence for a query, or nil while it's empty (the caller shows the
    /// static how-it-works hint instead).
    static func sentence(for query: String) -> String? {
        var phrases: [String] = []
        var sortSuffix = ""
        for token in tokenize(query) {
            if token.lowercased().hasPrefix("sort:") {
                sortSuffix = " Sorted by “\(String(token.dropFirst(5)))”."
            } else {
                phrases.append(phrase(for: token))
            }
        }
        guard !phrases.isEmpty else { return nil }
        return "This tab shows pull requests that " + phrases.joined(separator: ", and ") + "." + sortSuffix
    }

    /// One filter as a clause completing "pull requests that …".
    private static func phrase(for token: String) -> String {
        let negated = token.hasPrefix("-")
        let token = negated ? String(token.dropFirst()) : token

        guard let colon = token.firstIndex(of: ":"), colon != token.startIndex else {
            // A bare word searches titles and bodies.
            let word = unquote(token)
            return negated ? "don't mention “\(word)”" : "mention “\(word)”"
        }
        let key = token[..<colon].lowercased()
        let value = unquote(String(token[token.index(after: colon)...]))
        guard !value.isEmpty else { return "match “\(token)”" }

        // Negation reads clean only where we phrase it deliberately; anything
        // else negated stays literal rather than risking a garbled sentence.
        if negated {
            switch key {
            case "author": return value == "@me" ? "you didn't open" : "weren't opened by \(value)"
            case "label":  return "don't have the “\(value)” label"
            default:       return "don't match “\(token)”"
            }
        }

        switch (key, value.lowercased()) {
        case ("is", "pr"):                          return "are pull requests"
        case ("is", "open"), ("state", "open"):     return "are open"
        case ("is", "closed"), ("state", "closed"): return "are closed"
        case ("is", "merged"):                      return "are merged"
        case ("is", "draft"), ("draft", "true"):    return "are drafts"
        case ("draft", "false"):                    return "aren't drafts"
        case ("archived", "false"):                 return "aren't in archived repos"
        case ("review", "approved"):                return "are approved"
        case ("review", "changes_requested"):       return "have changes requested"
        case ("review", "required"):                return "still need a review"
        case ("review", "none"):                    return "have no review yet"
        case ("author", _):           return value == "@me" ? "you opened" : "were opened by \(value)"
        case ("assignee", _):         return value == "@me" ? "are assigned to you" : "are assigned to \(value)"
        case ("mentions", _):         return value == "@me" ? "mention you" : "mention \(value)"
        case ("reviewed-by", _):      return value == "@me" ? "you already reviewed" : "\(value) already reviewed"
        case ("review-requested", _), ("user-review-requested", _):
            return value == "@me" ? "want your review" : "want \(value)'s review"
        case ("team-review-requested", _): return "want a review from \(value)"
        case ("repo", _):             return "live in \(value)"
        case ("org", _), ("user", _): return "live under \(value)"
        case ("label", _):            return "have the “\(value)” label"
        case ("milestone", _):        return "are in the “\(value)” milestone"
        case ("base", _):             return "target the \(value) branch"
        case ("head", _):             return "come from the \(value) branch"
        default:                      return "match “\(token)”"
        }
    }

    /// Split on whitespace, keeping quoted segments (`label:"release blocker"`) whole.
    private static func tokenize(_ query: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false
        for character in query {
            if character == "\"" {
                inQuotes.toggle()
                current.append(character)
            } else if character.isWhitespace && !inQuotes {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Surrounding quotes are search syntax, not part of the value we display.
    private static func unquote(_ value: String) -> String {
        var value = value
        if value.hasPrefix("\"") { value.removeFirst() }
        if value.hasSuffix("\"") { value.removeLast() }
        return value
    }
}

#Preview("Create") {
    CustomTabEditor(mode: .create)
        .environment(AppModel(secrets: InMemorySecretStore()))
}

#Preview("Edit") {
    CustomTabEditor(mode: .edit(CustomTab(name: "Release blockers", query: "is:open label:release-blocker")))
        .environment(AppModel(secrets: InMemorySecretStore()))
}
