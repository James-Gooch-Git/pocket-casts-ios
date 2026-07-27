import Foundation

public struct CatalogueResponse: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let productName: String
    public let podcasts: [CataloguePodcast]
    public let pagination: Pagination

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case productName = "product_name"
        case podcasts
        case pagination
    }
}

public struct CataloguePodcast: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String?
}

public struct PodcastDetailResponse: Codable, Equatable, Identifiable, Sendable {
    public let schemaVersion: String
    public let id: UUID
    public let title: String
    public let description: String?
    public let groups: [EpisodeGroup]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case id
        case title
        case description
        case groups
    }
}

public struct EpisodeGroup: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case subject
        case series
        case other
    }

    public var id: String { "\(kind.rawValue):\(key)" }

    public let kind: Kind
    public let key: String
    public let title: String
    public let topic: String
    public let episodes: [EpisodeSummary]

    public init(
        kind: Kind,
        key: String,
        title: String,
        topic: String,
        episodes: [EpisodeSummary]
    ) {
        self.kind = kind
        self.key = key
        self.title = title
        self.topic = topic
        self.episodes = episodes
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case key
        case title
        case topic
        case episodes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(Kind.self, forKey: .kind)
        key = try container.decode(String.self, forKey: .key)
        title = try container.decode(String.self, forKey: .title)
        topic = try container.decodeIfPresent(String.self, forKey: .topic) ?? "Other"
        episodes = try container.decode([EpisodeSummary].self, forKey: .episodes)
    }
}

public struct EpisodeSummary: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let sourceGUID: String
    public let title: String
    public let showNotes: String?
    public let audioURL: URL?
    public let publishedAt: Date?
    public let seriesKey: String?
    public let seriesOrder: Int?
    public let subjects: [String]

    public init(
        id: UUID,
        sourceGUID: String,
        title: String,
        showNotes: String? = nil,
        audioURL: URL? = nil,
        publishedAt: Date? = nil,
        seriesKey: String? = nil,
        seriesOrder: Int? = nil,
        subjects: [String] = []
    ) {
        self.id = id
        self.sourceGUID = sourceGUID
        self.title = title
        self.showNotes = showNotes
        self.audioURL = audioURL
        self.publishedAt = publishedAt
        self.seriesKey = seriesKey
        self.seriesOrder = seriesOrder
        self.subjects = subjects
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sourceGUID = "source_guid"
        case title
        case showNotes = "show_notes"
        case audioURL = "audio_url"
        case publishedAt = "published_at"
        case seriesKey = "series_key"
        case seriesOrder = "series_order"
        case subjects
    }
}

public struct Pagination: Codable, Equatable, Sendable {
    public let offset: Int
    public let limit: Int
    public let returned: Int
}

public struct SmartPlaylistRequest: Codable, Equatable, Sendable {
    public let prompt: String
    public let podcastID: UUID?
    public let limit: Int

    public init(prompt: String, podcastID: UUID? = nil, limit: Int = 20) {
        self.prompt = prompt
        self.podcastID = podcastID
        self.limit = limit
    }

    enum CodingKeys: String, CodingKey {
        case prompt
        case podcastID = "podcast_id"
        case limit
    }
}

public struct SmartPlaylistResponse: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let prompt: String
    public let scope: String
    public let planner: String
    public let fallbackUsed: Bool
    public let items: [SmartPlaylistItem]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case prompt
        case scope
        case planner
        case fallbackUsed = "fallback_used"
        case items
    }
}

public struct SmartPlaylistItem: Codable, Equatable, Identifiable, Sendable {
    public let episodeID: UUID
    public let podcastID: UUID
    public let podcastTitle: String
    public let episodeTitle: String
    public let publishedAt: Date?
    public let seriesKey: String?
    public let seriesOrder: Int?
    public let reason: String

    public var id: UUID { episodeID }

    enum CodingKeys: String, CodingKey {
        case episodeID = "episode_id"
        case podcastID = "podcast_id"
        case podcastTitle = "podcast_title"
        case episodeTitle = "episode_title"
        case publishedAt = "published_at"
        case seriesKey = "series_key"
        case seriesOrder = "series_order"
        case reason
    }
}

// MARK: - Podcast search

public struct PodcastSearchRequest: Codable, Equatable, Sendable {
    public let query: String
    public let limit: Int

    public init(query: String, limit: Int = 25) {
        self.query = query
        self.limit = limit
    }
}

public struct PodcastSearchResponse: Codable, Equatable, Sendable {
    public let results: [PodcastSearchResult]

    public init(results: [PodcastSearchResult]) {
        self.results = results
    }
}

public struct PodcastSearchResult: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let author: String?
    public let description: String?
    public let feedURL: String
    public let artworkURL: String?
    public let episodeCount: Int?
    public let lastPublished: Date?

    public init(
        id: String,
        title: String,
        author: String? = nil,
        description: String? = nil,
        feedURL: String,
        artworkURL: String? = nil,
        episodeCount: Int? = nil,
        lastPublished: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.description = description
        self.feedURL = feedURL
        self.artworkURL = artworkURL
        self.episodeCount = episodeCount
        self.lastPublished = lastPublished
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case description
        case feedURL = "feed_url"
        case artworkURL = "artwork_url"
        case episodeCount = "episode_count"
        case lastPublished = "last_published"
    }
}

// MARK: - Subscribe

public struct SubscribeRequest: Codable, Equatable, Sendable {
    public let feedURL: String

    public init(feedURL: String) {
        self.feedURL = feedURL
    }

    enum CodingKeys: String, CodingKey {
        case feedURL = "feed_url"
    }
}

public struct SubscribeResponse: Codable, Equatable, Sendable {
    public let podcastUUID: String
    public let title: String
    public let episodesAdded: Int

    public init(podcastUUID: String, title: String, episodesAdded: Int) {
        self.podcastUUID = podcastUUID
        self.title = title
        self.episodesAdded = episodesAdded
    }

    enum CodingKeys: String, CodingKey {
        case podcastUUID = "podcast_uuid"
        case title
        case episodesAdded = "episodes_added"
    }
}

// MARK: - Client protocol

public protocol LibraryAPIClient: Sendable {
    func catalogue() async throws -> CatalogueResponse
    func podcast(id: UUID) async throws -> PodcastDetailResponse
    func smartPlaylist(request: SmartPlaylistRequest) async throws -> SmartPlaylistResponse
    func searchPodcasts(request: PodcastSearchRequest) async throws -> PodcastSearchResponse
    func subscribe(request: SubscribeRequest) async throws -> SubscribeResponse
}

public struct HTTPLibraryAPIClient: LibraryAPIClient {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func catalogue() async throws -> CatalogueResponse {
        let url = baseURL.appending(path: "v1/catalogue")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw LibraryAPIError.unsuccessfulResponse
        }
        return try decoder.decode(CatalogueResponse.self, from: data)
    }

    public func podcast(id: UUID) async throws -> PodcastDetailResponse {
        let url = baseURL.appending(path: "v1/podcasts/\(id.uuidString)")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw LibraryAPIError.unsuccessfulResponse
        }
        return try decoder.decode(PodcastDetailResponse.self, from: data)
    }

    public func smartPlaylist(request: SmartPlaylistRequest) async throws -> SmartPlaylistResponse {
        let url = baseURL.appending(path: "v1/playlists/smart")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw LibraryAPIError.unsuccessfulResponse
        }
        return try decoder.decode(SmartPlaylistResponse.self, from: data)
    }

    public func searchPodcasts(request: PodcastSearchRequest) async throws -> PodcastSearchResponse {
        var components = URLComponents(url: baseURL.appending(path: "v1/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: request.query),
            URLQueryItem(name: "limit", value: String(request.limit))
        ]
        let (data, response) = try await session.data(from: components.url!)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw LibraryAPIError.unsuccessfulResponse
        }
        return try decoder.decode(PodcastSearchResponse.self, from: data)
    }

    public func subscribe(request: SubscribeRequest) async throws -> SubscribeResponse {
        let url = baseURL.appending(path: "v1/subscribe")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw LibraryAPIError.unsuccessfulResponse
        }
        return try decoder.decode(SubscribeResponse.self, from: data)
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public enum LibraryAPIError: Error, Equatable {
    case unsuccessfulResponse
}
