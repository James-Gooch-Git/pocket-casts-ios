import PocketCastsDataModel
import PocketCastsServer
import PodcastriaLibrary
import SwiftUI
import UIKit

/// App-owned composition adapter between the original Podcastria module and
/// inherited navigation, persistence, and playback infrastructure.
final class PodcastriaLibraryViewController: UIViewController {
    private let playbackAdapter = PodcastriaPlaybackAdapter()

    override func viewDidLoad() {
        super.viewDidLoad()

        let library = LibraryView(
            client: HTTPLibraryAPIClient(baseURL: Self.apiBaseURL),
            onSelectEpisode: { [weak self] request in
                Task { @MainActor in
                    self?.playbackAdapter.play(request, presentingFrom: self)
                }
            },
            onSubscribed: { response in
                ServerPodcastManager.shared.addFromUuid(
                    podcastUuid: response.podcastUUID,
                    subscribe: true,
                    completion: nil
                )
            }
        )
        let host = UIHostingController(rootView: library)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private static var apiBaseURL: URL {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "PodcastriaAPIBaseURL") as? String,
           let url = URL(string: configured) {
            return url
        }
        return URL(string: "http://127.0.0.1:8000")!
    }
}

@MainActor
final class PodcastriaPlaybackAdapter {
    private let resolver: PodcastriaEpisodeResolver

    init(resolver: PodcastriaEpisodeResolver = PodcastriaEpisodeResolver()) {
        self.resolver = resolver
    }

    func play(_ request: LibraryPlaybackRequest, presentingFrom controller: UIViewController?) {
        guard let episode = resolver.resolve(request) else {
            let alert = UIAlertController(
                title: L10n.podcastriaEpisodeUnavailableTitle,
                message: L10n.podcastriaEpisodeUnavailableMessage,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.ok, style: .default))
            controller?.present(alert, animated: true)
            return
        }

        PlaybackManager.shared.load(episode: episode, autoPlay: true, overrideUpNext: false)
    }
}

// MARK: - Resolution

/// Turns a curated catalogue episode into a `BaseEpisode` the inherited playback
/// stack can load.
///
/// The catalogue is a separate backend from the podcasts in the local database,
/// so most curated episodes have no local counterpart. Rather than refusing to
/// play those, we materialise them: the curated show becomes an unsubscribed
/// local podcast and the episode becomes a streamable row hanging off it. This
/// mirrors how the app already backfills sparse Up Next items in
/// `ServerPodcastManager.addToDatabase(upNextItem:to:)`.
struct PodcastriaEpisodeResolver {
    private let store: PodcastriaEpisodeStore
    private let mappings: PodcastriaEpisodeIdentityStore

    init(
        store: PodcastriaEpisodeStore = DataManagerPodcastriaStore(),
        mappings: PodcastriaEpisodeIdentityStore = PodcastriaEpisodeIdentityStore()
    ) {
        self.store = store
        self.mappings = mappings
    }

    func resolve(_ request: LibraryPlaybackRequest) -> BaseEpisode? {
        let summary = request.episode

        // 1. Already resolved on a previous play.
        if let localUUID = mappings.localUUID(for: summary.id) {
            if let episode = store.findBaseEpisode(uuid: localUUID) {
                return episode
            }
            // The episode was deleted underneath us; drop the stale mapping.
            mappings.remove(backendUUID: summary.id)
        }

        guard let audioURL = summary.audioURL?.absoluteString else { return nil }

        // 2. The user already has this episode via a real podcast subscription.
        //    Prefer that copy so playback position and sync keep working.
        if let existing = store.findEpisodes(downloadURL: audioURL).first {
            mappings.set(localUUID: existing.uuid, for: summary.id)
            return existing
        }

        // 3. Nothing local: materialise the curated episode.
        return ingest(request, audioURL: audioURL)
    }

    private func ingest(_ request: LibraryPlaybackRequest, audioURL: String) -> BaseEpisode? {
        let episodeUUID = Self.localUUID(for: request.episode.id)

        // A previous ingest may have survived while its mapping did not.
        if let existing = store.findBaseEpisode(uuid: episodeUUID) {
            mappings.set(localUUID: episodeUUID, for: request.episode.id)
            return existing
        }

        guard let podcast = ensurePodcast(for: request) else { return nil }

        let episode = Episode()
        episode.uuid = episodeUUID
        episode.podcastUuid = podcast.uuid
        episode.podcast_id = podcast.id
        episode.title = request.episode.title
        episode.downloadUrl = audioURL
        episode.detailedDescription = request.episode.showNotes
        episode.publishedDate = request.episode.publishedAt
        episode.addedDate = Date()
        episode.playingStatus = PlayingStatus.notPlayed.rawValue
        episode.episodeStatus = DownloadStatus.notDownloaded.rawValue
        if let order = request.episode.seriesOrder {
            episode.episodeNumber = Int64(order)
        }
        store.save(episode: episode)

        mappings.set(localUUID: episodeUUID, for: request.episode.id)
        return episode
    }

    /// Curated shows are stored unsubscribed: they are catalogue entries the
    /// user browsed, not podcasts they chose to follow, so they stay out of the
    /// home grid while still giving episodes a parent row to hang off.
    private func ensurePodcast(for request: LibraryPlaybackRequest) -> Podcast? {
        let uuid = Self.localUUID(for: request.podcastID)
        if let existing = store.findPodcast(uuid: uuid) { return existing }

        let podcast = Podcast()
        podcast.uuid = uuid
        podcast.title = request.podcastTitle
        podcast.podcastDescription = request.podcastDescription
        podcast.addedDate = Date()
        podcast.subscribed = 0
        podcast.syncStatus = SyncStatus.notSynced.rawValue
        store.save(podcast: podcast)

        // `save(podcast:)` assigns the row id in place; without it episodes
        // cannot be attached.
        guard podcast.id != 0 else { return nil }
        return podcast
    }

    private static func localUUID(for backendUUID: UUID) -> String {
        backendUUID.uuidString.lowercased()
    }
}

// MARK: - Storage seams

/// The subset of `DataManager` the resolver needs, extracted so the resolution
/// and ingestion rules can be tested without a database.
protocol PodcastriaEpisodeStore {
    func findBaseEpisode(uuid: String) -> BaseEpisode?
    func findEpisodes(downloadURL: String) -> [Episode]
    func findPodcast(uuid: String) -> Podcast?
    func save(podcast: Podcast)
    func save(episode: BaseEpisode)
}

struct DataManagerPodcastriaStore: PodcastriaEpisodeStore {
    private let dataManager = DataManager.sharedManager

    func findBaseEpisode(uuid: String) -> BaseEpisode? {
        dataManager.findBaseEpisode(uuid: uuid)
    }

    func findEpisodes(downloadURL: String) -> [Episode] {
        dataManager.findEpisodesWhere(customWhere: "downloadUrl = ?", arguments: [downloadURL])
    }

    func findPodcast(uuid: String) -> Podcast? {
        dataManager.findPodcast(uuid: uuid, includeUnsubscribed: true)
    }

    func save(podcast: Podcast) {
        dataManager.save(podcast: podcast)
    }

    func save(episode: BaseEpisode) {
        dataManager.save(episode: episode)
    }
}

struct PodcastriaEpisodeIdentityStore {
    private let defaults: UserDefaults
    private let key = "Podcastria.backendToLocalEpisodeUUIDs.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func localUUID(for backendUUID: UUID) -> String? {
        mappings[backendUUID.uuidString.lowercased()]
    }

    func set(localUUID: String, for backendUUID: UUID) {
        var updated = mappings
        updated[backendUUID.uuidString.lowercased()] = localUUID
        defaults.set(updated, forKey: key)
    }

    func remove(backendUUID: UUID) {
        var updated = mappings
        updated.removeValue(forKey: backendUUID.uuidString.lowercased())
        defaults.set(updated, forKey: key)
    }

    private var mappings: [String: String] {
        defaults.dictionary(forKey: key) as? [String: String] ?? [:]
    }
}
