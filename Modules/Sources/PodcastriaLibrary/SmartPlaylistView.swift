import SwiftUI

@available(iOS 16, macOS 12, tvOS 16, watchOS 9, *)
struct SmartPlaylistView: View {
    private let client: any LibraryAPIClient
    private let podcastID: UUID?
    private let podcastTitle: String?
    private let submitsOnAppear: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var prompt: String
    @State private var response: SmartPlaylistResponse?
    @State private var errorMessage: String?
    @State private var isLoading = false

    init(
        client: any LibraryAPIClient,
        podcastID: UUID?,
        podcastTitle: String?,
        initialPrompt: String = "Teach me Ancient Rome in chronological order",
        submitsOnAppear: Bool = false
    ) {
        self.client = client
        self.podcastID = podcastID
        self.podcastTitle = podcastTitle
        self.submitsOnAppear = submitsOnAppear
        _prompt = State(initialValue: initialPrompt)
    }

    private var palette: PodcastriaDesign.Palette {
        PodcastriaDesign.palette(for: colorScheme)
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    TextField("What do you want to learn?", text: $prompt, axis: .vertical)
                        .lineLimit(2 ... 5)
                        .accessibilityIdentifier("smart-playlist-prompt")

                    Button {
                        Task { await buildPlaylist() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                            }
                            Text(isLoading ? "Building…" : "Build learning path")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || prompt.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
                    .accessibilityIdentifier("smart-playlist-build")
                } header: {
                    PodcastriaMetaLabel(
                        text: podcastTitle.map { "Within \($0)" } ?? "Across the curated catalogue",
                        color: palette.accent
                    )
                } footer: {
                    Text("Podcastria turns your request into a structured, explainable episode path.")
                }

                if let errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The learning path could not be built.")
                                .font(.podcastriaDisplay(.headline))
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                    }
                }

                if let response {
                    Section {
                        if response.items.isEmpty {
                            Text("No matching episodes were found. Try a broader request.")
                                .foregroundStyle(palette.secondaryText)
                        } else {
                            ForEach(Array(response.items.enumerated()), id: \.element.id) { index, item in
                                resultRow(position: index + 1, item: item)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Learning path")
                            Spacer()
                            PodcastriaMetaLabel(
                                text: plannerLabel(response),
                                color: response.fallbackUsed ? palette.tertiaryText : palette.accent
                            )
                        }
                    } footer: {
                        Text("Each reason comes from deterministic matching against the approved catalogue.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Smart playlist")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
        .tint(palette.accent)
        .task {
            if submitsOnAppear, response == nil {
                await buildPlaylist()
            }
        }
    }

    private func resultRow(position: Int, item: SmartPlaylistItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(position)")
                .font(.podcastriaMeta)
                .foregroundStyle(palette.accent)
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.episodeTitle)
                    .font(.podcastriaDisplay(.headline))
                    .foregroundStyle(palette.text)
                Text(item.podcastTitle)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                Text(item.reason)
                    .font(.caption)
                    .foregroundStyle(palette.tertiaryText)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("smart-playlist-result-\(position)")
    }

    private func plannerLabel(_ response: SmartPlaylistResponse) -> String {
        if response.planner == "cache" {
            return "Cached plan · \(response.items.count) ep"
        }
        if response.fallbackUsed {
            return "Term match · \(response.items.count) ep"
        }
        return "AI planned · \(response.items.count) ep"
    }

    @MainActor
    private func buildPlaylist() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            response = try await client.smartPlaylist(
                request: SmartPlaylistRequest(
                    prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                    podcastID: podcastID
                )
            )
        } catch {
            response = nil
            errorMessage = error.localizedDescription
        }
    }
}
