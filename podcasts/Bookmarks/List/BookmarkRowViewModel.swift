import SwiftUI
import PocketCastsUtils
import PocketCastsDataModel
import PocketCastsServer

class BookmarkRowViewModel: ObservableObject {
    private(set) var bookmark: Bookmark

    @Published private(set) var heading: String?
    @Published private(set) var title: String
    let subtitle: String
    let playButton: String
    @Published private(set) var episode: BaseEpisode?

    private var loadEpisodeTask: Task<Void, Never>?

    init(bookmark: Bookmark) {
        self.bookmark = bookmark
        self.episode = bookmark.episode
        self.title = bookmark.title
        self.playButton = TimeFormatter.shared.playTimeFormat(time: bookmark.time)
        self.subtitle = DateFormatter.localizedString(from: bookmark.created,
                                                      dateStyle: .medium,
                                                      timeStyle: .short)
        if let episode {
            updateFromEpisode(episode)
        } else {
            loadEpisode(from: bookmark)
        }
    }

    deinit {
        loadEpisodeTask?.cancel()
    }

    /// Applies changes from a newer version of the same bookmark, e.g. after its title was edited
    func update(from bookmark: Bookmark) {
        self.bookmark = bookmark

        if title != bookmark.title {
            title = bookmark.title
        }

        if let episode = bookmark.episode, episode.uuid != self.episode?.uuid {
            updateFromEpisode(episode)
        }
    }

    private func updateFromEpisode(_ episode: BaseEpisode) {
        self.episode = episode
        self.heading = episode.title
    }

    private func loadEpisode(from bookmark: Bookmark) {
        // Get the bookmark's BaseEpisode so we can load it
        let dataManager = DataManager.sharedManager
        if let episode = bookmark.episode ?? dataManager.findBaseEpisode(uuid: bookmark.episodeUuid) {
            updateFromEpisode(episode)
        } else if let podcastUuid = bookmark.podcastUuid {
            loadEpisodeTask = Task { [weak self] in
                guard let episode = try? await ServerPodcastManager.shared.addMissingPodcastAndEpisode(episodeUuid: bookmark.episodeUuid, podcastUuid: podcastUuid),
                      let self, !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self.updateFromEpisode(episode)
                }
            }
        }
    }
}
