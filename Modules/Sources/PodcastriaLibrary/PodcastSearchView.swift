import SwiftUI

@available(iOS 16, macOS 12, tvOS 16, watchOS 9, *)
public struct PodcastSearchView: View {
    private let client: any LibraryAPIClient
    private let onSubscribed: @Sendable (SubscribeResponse) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [PodcastSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var subscribingIDs: Set<String> = []
    @State private var subscribedIDs: Set<String> = []
    @State private var searchTask: Task<Void, Never>?

    public init(
        client: any LibraryAPIClient,
        onSubscribed: @escaping @Sendable (SubscribeResponse) -> Void
    ) {
        self.client = client
        self.onSubscribed = onSubscribed
    }

    private var palette: PodcastriaDesign.Palette {
        PodcastriaDesign.palette(for: colorScheme)
    }

    public var body: some View {
        NavigationView {
            Group {
                if results.isEmpty, !isSearching, query.isEmpty {
                    emptyState
                } else if results.isEmpty, !isSearching {
                    noResultsState
                } else {
                    resultsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background)
            .navigationTitle("Find podcasts")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
        .tint(palette.accent)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search by name, topic, or host"
        )
        .onChange(of: query) { _ in
            debounceSearch()
        }
        .onSubmit(of: .search) {
            searchTask?.cancel()
            Task { await performSearch() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(palette.tertiaryText)
            Text("Search for any podcast")
                .font(.podcastriaDisplay(.headline))
                .foregroundStyle(palette.text)
            Text("Find shows by name, topic, or host.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
        }
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(palette.tertiaryText)
            Text("No podcasts found")
                .font(.podcastriaDisplay(.headline))
                .foregroundStyle(palette.text)
            Text("Try a different name or topic.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
        }
    }

    private var resultsList: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .listRowBackground(Color.clear)
            }

            ForEach(results) { result in
                resultRow(result)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(palette.hairline)
            }

            if isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func resultRow(_ result: PodcastSearchResult) -> some View {
        HStack(alignment: .top, spacing: 14) {
            artworkView(result)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.podcastriaDisplay(.headline))
                    .foregroundStyle(palette.text)
                    .lineLimit(2)

                if let author = result.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }

                if let description = result.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(palette.tertiaryText)
                        .lineLimit(2)
                }

                metaLine(result)
            }

            Spacer(minLength: 0)

            subscribeButton(result)
        }
        .padding(.vertical, 6)
    }

    private func artworkView(_ result: PodcastSearchResult) -> some View {
        Group {
            if let urlString = result.artworkURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        placeholderSquare(result.title)
                    }
                }
            } else {
                placeholderSquare(result.title)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(palette.cardBorder)
        )
    }

    private func placeholderSquare(_ title: String) -> some View {
        Text(LibraryView.initials(for: title))
            .font(.podcastriaMeta)
            .kerning(1)
            .foregroundStyle(palette.tertiaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.artworkPlaceholder)
    }

    private func metaLine(_ result: PodcastSearchResult) -> some View {
        HStack(spacing: 6) {
            if let count = result.episodeCount {
                PodcastriaMetaLabel(
                    text: "\(count) ep",
                    color: palette.tertiaryText
                )
            }
            if let date = result.lastPublished {
                PodcastriaMetaLabel(
                    text: date.formatted(.dateTime.month(.abbreviated).year()),
                    color: palette.tertiaryText
                )
            }
        }
    }

    @ViewBuilder
    private func subscribeButton(_ result: PodcastSearchResult) -> some View {
        if subscribedIDs.contains(result.id) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(palette.accent)
                .imageScale(.large)
        } else if subscribingIDs.contains(result.id) {
            ProgressView()
        } else {
            Button {
                Task { await subscribe(to: result) }
            } label: {
                Image(systemName: "plus.circle")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.accent)
            .accessibilityLabel("Subscribe to \(result.title)")
        }
    }

    // MARK: - Actions

    private func debounceSearch() {
        searchTask?.cancel()
        let currentQuery = query
        guard currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    @MainActor
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            let response = try await client.searchPodcasts(
                request: PodcastSearchRequest(query: trimmed)
            )
            results = response.results
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func subscribe(to result: PodcastSearchResult) async {
        subscribingIDs.insert(result.id)
        defer { subscribingIDs.remove(result.id) }

        do {
            let response = try await client.subscribe(
                request: SubscribeRequest(feedURL: result.feedURL)
            )
            subscribedIDs.insert(result.id)
            onSubscribed(response)
        } catch {
            errorMessage = "Could not subscribe to \(result.title): \(error.localizedDescription)"
        }
    }
}
