import Foundation

/// Everything the host app needs in order to turn a curated catalogue episode
/// into something playable.
///
/// `EpisodeSummary` on its own is not enough: the host has to be able to attach
/// the episode to a podcast in its local database, and the summary carries no
/// podcast identity. This bundles the episode with the show it was browsed from.
public struct LibraryPlaybackRequest: Equatable, Sendable {
    public let episode: EpisodeSummary
    public let podcastID: UUID
    public let podcastTitle: String
    public let podcastDescription: String?

    public init(
        episode: EpisodeSummary,
        podcastID: UUID,
        podcastTitle: String,
        podcastDescription: String? = nil
    ) {
        self.episode = episode
        self.podcastID = podcastID
        self.podcastTitle = podcastTitle
        self.podcastDescription = podcastDescription
    }
}

public extension PodcastDetailResponse {
    func playbackRequest(for episode: EpisodeSummary) -> LibraryPlaybackRequest {
        LibraryPlaybackRequest(
            episode: episode,
            podcastID: id,
            podcastTitle: title,
            podcastDescription: description
        )
    }
}
