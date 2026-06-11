import SwiftUI

/// A reusable inline search field for selecting an existing related item or
/// creating a new one when no matching result exists.
public struct SagaInlineSearchCreateField<Item: Identifiable, RowContent: View, SelectedContent: View>: View {
    @Binding private var query: String
    private let selectedItem: Item?
    private let results: [Item]
    private let isSearching: Bool
    private let placeholder: String
    private let createTitle: (String) -> String
    private let createSubtitle: String
    private let debounceNanoseconds: UInt64
    private let onDebouncedQueryChange: @MainActor (String) -> Void
    private let onSelect: (Item) -> Void
    private let onClearSelection: () -> Void
    private let onCreate: (String) -> Void
    private let rowContent: (Item) -> RowContent
    private let selectedContent: (Item) -> SelectedContent

    public init(
        query: Binding<String>,
        selectedItem: Item?,
        results: [Item],
        isSearching: Bool = false,
        placeholder: String,
        createSubtitle: String,
        debounceNanoseconds: UInt64 = 280_000_000,
        createTitle: @escaping (String) -> String,
        onDebouncedQueryChange: @escaping @MainActor (String) -> Void,
        onSelect: @escaping (Item) -> Void,
        onClearSelection: @escaping () -> Void,
        onCreate: @escaping (String) -> Void,
        @ViewBuilder rowContent: @escaping (Item) -> RowContent,
        @ViewBuilder selectedContent: @escaping (Item) -> SelectedContent
    ) {
        _query = query
        self.selectedItem = selectedItem
        self.results = results
        self.isSearching = isSearching
        self.placeholder = placeholder
        self.createTitle = createTitle
        self.createSubtitle = createSubtitle
        self.debounceNanoseconds = debounceNanoseconds
        self.onDebouncedQueryChange = onDebouncedQueryChange
        self.onSelect = onSelect
        self.onClearSelection = onClearSelection
        self.onCreate = onCreate
        self.rowContent = rowContent
        self.selectedContent = selectedContent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            searchField

            if let selectedItem {
                selectedRow(selectedItem)
            } else if shouldShowDropdown {
                dropdown
            }
        }
        .task(id: query) {
            let currentQuery = query
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            guard !Task.isCancelled else { return }
            await onDebouncedQueryChange(currentQuery)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if !query.isEmpty {
                Button {
                    query = ""
                    onClearSelection()
                    onDebouncedQueryChange("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var shouldShowDropdown: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var dropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            if results.isEmpty {
                createRow
            } else {
                ForEach(results) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        rowContent(item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    if item.id != results.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var createRow: some View {
        Button {
            onCreate(query.trimmingCharacters(in: .whitespacesAndNewlines))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(createTitle(query.trimmingCharacters(in: .whitespacesAndNewlines)))
                        .font(.subheadline.weight(.semibold))
                    Text(createSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func selectedRow(_ item: Item) -> some View {
        HStack(spacing: 10) {
            selectedContent(item)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onClearSelection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
