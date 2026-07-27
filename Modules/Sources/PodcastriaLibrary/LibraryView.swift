import SwiftUI

@available(iOS 16, macOS 12, tvOS 16, watchOS 9, *)
public struct LibraryView: View {
    private let client: any LibraryAPIClient
    private let onSelectEpisode: @Sendable (LibraryPlaybackRequest) -> Void
    private let onSubscribed: @Sendable (SubscribeResponse) -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var catalogue: CatalogueResponse?
    @State private var selectedPodcast: PodcastDetailResponse?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var expandedSeriesIDs = Set<String>()
    @State private var isShowingSmartPlaylist = false
    @State private var isShowingSearch = false

    public init(
        client: any LibraryAPIClient,
        onSelectEpisode: @escaping @Sendable (LibraryPlaybackRequest) -> Void,
        onSubscribed: @escaping @Sendable (SubscribeResponse) -> Void = { _ in }
    ) {
        self.client = client
        self.onSelectEpisode = onSelectEpisode
        self.onSubscribed = onSubscribed
    }

    /// Episode rows are only ever shown inside a selected podcast, so the
    /// podcast context needed for playback is always available here.
    private func select(_ episode: EpisodeSummary) {
        guard let selectedPodcast else { return }
        onSelectEpisode(selectedPodcast.playbackRequest(for: episode))
    }

    private var palette: PodcastriaDesign.Palette {
        PodcastriaDesign.palette(for: colorScheme)
    }

    public var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading library…")
                } else if let errorMessage {
                    errorView(errorMessage)
                } else if let selectedPodcast {
                    podcastView(selectedPodcast)
                } else if let catalogue {
                    catalogueView(catalogue)
                } else {
                    ProgressView("Loading library…")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background)
            .navigationTitle(selectedPodcast?.title ?? catalogue?.productName ?? "Podcastria Library")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if selectedPodcast != nil {
                        Button("Library") {
                            selectedPodcast = nil
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        isShowingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Find podcasts")
                    .accessibilityIdentifier("podcast-search-open")

                    Button("Smart playlist") {
                        isShowingSmartPlaylist = true
                    }
                    .accessibilityIdentifier("smart-playlist-open")
                }
            }
        }
        .tint(palette.accent)
        .sheet(isPresented: $isShowingSearch) {
            PodcastSearchView(client: client, onSubscribed: onSubscribed)
        }
        .sheet(isPresented: $isShowingSmartPlaylist) {
            SmartPlaylistView(
                client: client,
                podcastID: selectedPodcast?.id,
                podcastTitle: selectedPodcast?.title
            )
        }
        .task {
            await loadCatalogue()
        }
    }

    private func catalogueView(_ response: CatalogueResponse) -> some View {
        Group {
            if response.podcasts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.largeTitle)
                        .foregroundStyle(palette.tertiaryText)
                    Text("No podcasts available")
                        .font(.podcastriaDisplay(.headline))
                        .foregroundStyle(palette.text)
                    Text("The curated catalogue is currently empty.")
                        .foregroundStyle(palette.secondaryText)
                }
            } else {
                List(response.podcasts) { podcast in
                    Button {
                        Task { await loadPodcast(id: podcast.id) }
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            artworkPlaceholder(for: podcast.title, size: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(podcast.title)
                                    .font(.podcastriaDisplay(.title3))
                                    .foregroundStyle(palette.text)
                                if let description = podcast.description {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundStyle(palette.secondaryText)
                                        .lineLimit(3)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(palette.hairline)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func podcastView(_ podcast: PodcastDetailResponse) -> some View {
        let groups = LibraryFuzzySearch.groups(podcast.groups, matching: searchText)
        let topics = topicSections(groups)

        return ScrollViewReader { proxy in
            List {
                if let description = podcast.description, searchText.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if podcast.groups.isEmpty {
                    Text("No organised episodes are available for this show.")
                        .foregroundStyle(palette.secondaryText)
                        .listRowBackground(Color.clear)
                } else if topics.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(palette.tertiaryText)
                        Text("No matching groups or episodes")
                            .font(.podcastriaDisplay(.headline))
                            .foregroundStyle(palette.text)
                        Text("Try a different spelling or a broader term.")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(topics) { topic in
                        Section {
                            ForEach(topic.groups) { group in
                                if group.kind == .series {
                                    seriesCard(group)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                } else {
                                    subjectGroup(group)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparatorTint(palette.hairline)
                                }
                            }
                        } header: {
                            topicHeader(topic)
                        }
                        .id(topic.id)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search groups and episodes"
            )
            .overlay(alignment: .trailing) {
                if searchText.isEmpty, topics.count > 1 {
                    alphabetRail(topics, proxy: proxy)
                }
            }
        }
    }

    private func topicHeader(_ topic: TopicSection) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(topic.title)
                .font(.podcastriaDisplay(.title3))
                .foregroundStyle(palette.text)
            Spacer()
            PodcastriaMetaLabel(
                text: topicMeta(topic),
                color: palette.tertiaryText
            )
        }
        .textCase(nil)
        .padding(.top, 6)
    }

    private func topicMeta(_ topic: TopicSection) -> String {
        let episodeCount = topic.groups.reduce(0) { $0 + $1.episodes.count }
        let seriesCount = topic.groups.filter { $0.kind == .series }.count
        var parts = ["\(episodeCount) ep"]
        if seriesCount > 0 {
            parts.append("\(seriesCount) series")
        }
        return parts.joined(separator: " · ")
    }

    private func seriesCard(_ group: EpisodeGroup) -> some View {
        DisclosureGroup(isExpanded: seriesExpansionBinding(for: group)) {
            VStack(spacing: 0) {
                ForEach(Array(group.episodes.enumerated()), id: \.element.id) { index, episode in
                    seriesRow(episode, fallbackNumber: index + 1)
                    if episode.id != group.episodes.last?.id {
                        Divider().overlay(palette.hairline)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                PodcastriaMetaLabel(
                    text: "Series · \(group.episodes.count) parts",
                    color: palette.accent
                )
                Text(group.title)
                    .font(.podcastriaDisplay(.headline))
                    .foregroundStyle(palette.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(palette.cardBorder)
        )
        .accessibilityIdentifier("series-group-\(group.key)")
    }

    private func seriesExpansionBinding(for group: EpisodeGroup) -> Binding<Bool> {
        Binding(
            get: {
                !searchText.isEmpty || expandedSeriesIDs.contains(group.id)
            },
            set: { isExpanded in
                guard searchText.isEmpty else { return }
                if isExpanded {
                    expandedSeriesIDs.insert(group.id)
                } else {
                    expandedSeriesIDs.remove(group.id)
                }
            }
        )
    }

    private func seriesRow(_ episode: EpisodeSummary, fallbackNumber: Int) -> some View {
        Button {
            select(episode)
        } label: {
            HStack(spacing: 10) {
                Text("\(episode.seriesOrder ?? fallbackNumber)")
                    .font(.podcastriaMeta)
                    .foregroundStyle(palette.tertiaryText)
                    .frame(width: 18, alignment: .leading)
                Text(episode.title)
                    .font(.subheadline)
                    .foregroundStyle(episode.audioURL == nil ? palette.tertiaryText : palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let publishedAt = episode.publishedAt {
                    PodcastriaMetaLabel(
                        text: publishedAt.formatted(.dateTime.day().month(.abbreviated).year()),
                        color: palette.tertiaryText
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(episode.audioURL == nil)
    }

    private func subjectGroup(_ group: EpisodeGroup) -> some View {
        DisclosureGroup {
            ForEach(group.episodes) { episode in
                episodeButton(episode, in: group)
            }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text(group.title)
                    .font(.podcastriaDisplay(.headline))
                    .foregroundStyle(palette.text)
                Spacer()
                PodcastriaMetaLabel(
                    text: "\(group.episodes.count) ep",
                    color: palette.tertiaryText
                )
            }
        }
    }

    private func episodeButton(_ episode: EpisodeSummary, in group: EpisodeGroup) -> some View {
        Button {
            select(episode)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.subheadline)
                    .foregroundStyle(episode.audioURL == nil ? palette.tertiaryText : palette.text)
                HStack(spacing: 6) {
                    if group.kind == .series, let order = episode.seriesOrder {
                        PodcastriaMetaLabel(text: "Part \(order)", color: palette.accent)
                    }
                    if let publishedAt = episode.publishedAt {
                        PodcastriaMetaLabel(
                            text: publishedAt.formatted(.dateTime.day().month(.abbreviated).year()),
                            color: palette.tertiaryText
                        )
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(episode.audioURL == nil)
    }

    private func artworkPlaceholder(for title: String, size: CGFloat) -> some View {
        Text(Self.initials(for: title))
            .font(.podcastriaMeta)
            .kerning(1)
            .foregroundStyle(palette.tertiaryText)
            .frame(width: size, height: size)
            .background(palette.artworkPlaceholder, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(palette.cardBorder)
            )
            .accessibilityHidden(true)
    }

    static func initials(for title: String) -> String {
        let articles: Set<String> = ["a", "an", "the"]
        let words = title
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .filter { !articles.contains($0.lowercased()) }
        let source = words.isEmpty
            ? title.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            : words
        return source.prefix(3).compactMap(\.first).map(String.init).joined().uppercased()
    }

    private func topicSections(_ groups: [EpisodeGroup]) -> [TopicSection] {
        Dictionary(grouping: groups, by: \.topic)
            .map { topic, groups in
                TopicSection(title: topic, groups: groups.sorted { $0.title < $1.title })
            }
            .sorted {
                if $0.title == "Other" { return false }
                if $1.title == "Other" { return true }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    private func alphabetRail(_ topics: [TopicSection], proxy: ScrollViewProxy) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 1) {
                ForEach(alphabetEntries(topics), id: \.topicID) { entry in
                    Button(entry.letter) {
                        withAnimation {
                            proxy.scrollTo(entry.topicID, anchor: .top)
                        }
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: 24, height: 16)
                    .accessibilityLabel("Jump to topics beginning with \(entry.letter)")
                }
            }
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
        }
        .frame(maxHeight: 360)
        .padding(.trailing, 4)
    }

    private func alphabetEntries(_ topics: [TopicSection]) -> [AlphabetEntry] {
        var seen = Set<String>()
        return topics.compactMap { topic in
            guard let character = topic.title.first else { return nil }
            let letter = String(character).uppercased()
            guard seen.insert(letter).inserted else { return nil }
            return AlphabetEntry(letter: letter, topicID: topic.id)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("The library could not be loaded.")
                .foregroundStyle(palette.text)
            Text(message)
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
            Button("Try again") {
                Task { await loadCatalogue() }
            }
        }
        .padding()
    }

    @MainActor
    private func loadCatalogue() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            catalogue = try await client.catalogue()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadPodcast(id: UUID) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            selectedPodcast = try await client.podcast(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TopicSection: Identifiable {
    var id: String { title }
    let title: String
    let groups: [EpisodeGroup]
}

private struct AlphabetEntry {
    let letter: String
    let topicID: String
}
