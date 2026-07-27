import PodcastriaLibrary
import XCTest
@testable import PocketCastsDataModel
@testable import podcasts

final class PodcastriaEpisodeResolverTests: XCTestCase {
    private var store: FakePodcastriaStore!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        store = FakePodcastriaStore()
        suiteName = "PodcastriaEpisodeResolverTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeResolver() -> PodcastriaEpisodeResolver {
        PodcastriaEpisodeResolver(
            store: store,
            mappings: PodcastriaEpisodeIdentityStore(defaults: defaults)
        )
    }

    // MARK: - Ingestion

    func testIngestsCuratedEpisodeWhenNothingExistsLocally() throws {
        let request = Self.makeRequest()

        let resolved = try XCTUnwrap(makeResolver().resolve(request) as? Episode)

        XCTAssertEqual(resolved.uuid, request.episode.id.uuidString.lowercased())
        XCTAssertEqual(resolved.title, "Hannibal Crosses the Alps")
        XCTAssertEqual(resolved.downloadUrl, "https://audio.example.com/hannibal.mp3")
        XCTAssertEqual(resolved.podcastUuid, request.podcastID.uuidString.lowercased())
        XCTAssertEqual(resolved.playingStatus, PlayingStatus.notPlayed.rawValue)
        XCTAssertEqual(resolved.episodeStatus, DownloadStatus.notDownloaded.rawValue)
        XCTAssertEqual(store.savedEpisodes.count, 1)
    }

    func testIngestCreatesUnsubscribedPodcastForCuratedShow() throws {
        let request = Self.makeRequest()

        _ = makeResolver().resolve(request)

        let podcast = try XCTUnwrap(store.findPodcast(uuid: request.podcastID.uuidString.lowercased()))
        XCTAssertEqual(podcast.title, "The Rest Is History")
        XCTAssertEqual(podcast.subscribed, 0, "Curated shows must not appear as subscriptions")
        XCTAssertNotEqual(podcast.id, 0, "Episodes cannot be attached without a row id")
    }

    func testIngestedEpisodeLinksToItsPodcastRowId() throws {
        let request = Self.makeRequest()

        let resolved = try XCTUnwrap(makeResolver().resolve(request) as? Episode)
        let podcast = try XCTUnwrap(store.findPodcast(uuid: request.podcastID.uuidString.lowercased()))

        XCTAssertEqual(resolved.podcast_id, podcast.id)
    }

    func testSecondEpisodeFromSameShowReusesExistingPodcast() {
        let resolver = makeResolver()
        let podcastID = UUID()

        _ = resolver.resolve(Self.makeRequest(podcastID: podcastID))
        _ = resolver.resolve(Self.makeRequest(podcastID: podcastID, audioURL: "https://audio.example.com/cannae.mp3"))

        XCTAssertEqual(store.savedPodcasts.count, 1)
        XCTAssertEqual(store.savedEpisodes.count, 2)
    }

    // MARK: - Reuse

    func testPrefersExistingLocalEpisodeMatchedByAudioURL() throws {
        let existing = Episode()
        existing.uuid = "already-in-library"
        existing.downloadUrl = "https://audio.example.com/hannibal.mp3"
        store.episodesByDownloadURL["https://audio.example.com/hannibal.mp3"] = [existing]

        let resolved = try XCTUnwrap(makeResolver().resolve(Self.makeRequest()) as? Episode)

        XCTAssertEqual(resolved.uuid, "already-in-library")
        XCTAssertTrue(store.savedEpisodes.isEmpty, "An existing subscription copy must not be duplicated")
    }

    func testRepeatedPlaysReuseTheIngestedEpisode() {
        let resolver = makeResolver()
        let request = Self.makeRequest()

        _ = resolver.resolve(request)
        _ = resolver.resolve(request)

        XCTAssertEqual(store.savedEpisodes.count, 1)
    }

    func testStaleMappingIsDroppedAndEpisodeReingested() throws {
        let resolver = makeResolver()
        let request = Self.makeRequest()

        let first = try XCTUnwrap(resolver.resolve(request) as? Episode)

        // Simulate the user deleting the episode out from under the mapping.
        store.episodesByUUID.removeValue(forKey: first.uuid)
        store.episodesByDownloadURL.removeAll()

        let second = try XCTUnwrap(resolver.resolve(request) as? Episode)

        XCTAssertEqual(second.uuid, first.uuid)
        XCTAssertEqual(store.savedEpisodes.count, 2)
    }

    // MARK: - Unplayable

    func testReturnsNilWhenCuratedEpisodeHasNoAudio() {
        let request = Self.makeRequest(audioURL: nil)

        XCTAssertNil(makeResolver().resolve(request))
        XCTAssertTrue(store.savedEpisodes.isEmpty)
        XCTAssertTrue(store.savedPodcasts.isEmpty)
    }

    // MARK: - Helpers

    private static func makeRequest(
        podcastID: UUID = UUID(),
        episodeID: UUID = UUID(),
        audioURL: String? = "https://audio.example.com/hannibal.mp3"
    ) -> LibraryPlaybackRequest {
        LibraryPlaybackRequest(
            episode: EpisodeSummary(
                id: episodeID,
                sourceGUID: "guid-\(episodeID.uuidString)",
                title: "Hannibal Crosses the Alps",
                showNotes: "Elephants, mountains, and a very bad idea.",
                audioURL: audioURL.flatMap(URL.init(string:)),
                publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
                seriesKey: "punic-wars",
                seriesOrder: 3,
                subjects: ["Rome"]
            ),
            podcastID: podcastID,
            podcastTitle: "The Rest Is History",
            podcastDescription: "A curated history show"
        )
    }
}

// MARK: - Fake store

private final class FakePodcastriaStore: PodcastriaEpisodeStore {
    var episodesByUUID: [String: BaseEpisode] = [:]
    var episodesByDownloadURL: [String: [Episode]] = [:]
    var podcastsByUUID: [String: Podcast] = [:]

    private(set) var savedEpisodes: [BaseEpisode] = []
    private(set) var savedPodcasts: [Podcast] = []

    private var nextPodcastID: Int64 = 1

    func findBaseEpisode(uuid: String) -> BaseEpisode? {
        episodesByUUID[uuid]
    }

    func findEpisodes(downloadURL: String) -> [Episode] {
        episodesByDownloadURL[downloadURL] ?? []
    }

    func findPodcast(uuid: String) -> Podcast? {
        podcastsByUUID[uuid]
    }

    func save(podcast: Podcast) {
        // Mirrors DataManager, which assigns the row id in place on insert.
        if podcast.id == 0 {
            podcast.id = nextPodcastID
            nextPodcastID += 1
        }
        podcastsByUUID[podcast.uuid] = podcast
        savedPodcasts.append(podcast)
    }

    func save(episode: BaseEpisode) {
        episodesByUUID[episode.uuid] = episode
        if let episode = episode as? Episode, let url = episode.downloadUrl {
            episodesByDownloadURL[url, default: []].append(episode)
        }
        savedEpisodes.append(episode)
    }
}
