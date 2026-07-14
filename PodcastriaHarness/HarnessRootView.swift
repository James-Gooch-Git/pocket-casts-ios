import SwiftUI

struct HarnessRootView: View {
  @State private var selectedEpisodeTitle: String?

  private var client: any LibraryAPIClient {
    if let value = ProcessInfo.processInfo.environment["PODCASTRIA_API_BASE_URL"],
       let baseURL = URL(string: value) {
      return HTTPLibraryAPIClient(baseURL: baseURL)
    }
    return FixtureLibraryAPIClient()
  }

  private var shouldAutorunSmartPlaylist: Bool {
    ProcessInfo.processInfo.environment["PODCASTRIA_SMART_PLAYLIST_AUTORUN"] == "1"
  }

  var body: some View {
    Group {
      if shouldAutorunSmartPlaylist {
        SmartPlaylistView(
          client: client,
          podcastID: nil,
          podcastTitle: nil,
          submitsOnAppear: true
        )
      } else {
        LibraryView(client: client) { episode in
          Task { @MainActor in
            selectedEpisodeTitle = episode.title
          }
        }
      }
    }
    .alert(
      "Playback adapter",
      isPresented: Binding(
        get: { selectedEpisodeTitle != nil },
        set: { if !$0 { selectedEpisodeTitle = nil } }
      )
    ) {
      Button("OK", role: .cancel) {
        selectedEpisodeTitle = nil
      }
    } message: {
      Text(
        "The harness selected \(selectedEpisodeTitle ?? "this episode"). The full staging app verifies inherited playback."
      )
    }
  }
}

private struct FixtureLibraryAPIClient: LibraryAPIClient {
  func catalogue() async throws -> CatalogueResponse {
    try Self.decode(Self.catalogueJSON)
  }

  func podcast(id: UUID) async throws -> PodcastDetailResponse {
    try Self.decode(Self.podcastJSON)
  }

  func smartPlaylist(request: SmartPlaylistRequest) async throws -> SmartPlaylistResponse {
    try Self.decode(Self.smartPlaylistJSON)
  }

  private static func decode<Value: Decodable>(_ json: String) throws -> Value {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Value.self, from: Data(json.utf8))
  }

  private static let catalogueJSON = #"""
    {
      "schema_version": "1.0",
      "product_name": "Podcastria Harness",
      "podcasts": [
        {
          "id": "7F31CCEE-87A8-4E62-B3DB-0D5FE03C8E62",
          "title": "The Rest Is History",
          "description": "Fixture catalogue data for rapid UI development."
        }
      ],
      "pagination": { "offset": 0, "limit": 20, "returned": 1 }
    }
    """#

  private static let podcastJSON = #"""
    {
      "schema_version": "1.1",
      "id": "7F31CCEE-87A8-4E62-B3DB-0D5FE03C8E62",
      "title": "The Rest Is History",
      "description": "Explore fixture topics, series, search, expansion and episode selection without running the backend.",
      "groups": [
        {
          "kind": "series",
          "key": "fall-of-rome",
          "title": "The Fall of Rome",
          "topic": "Ancient Rome",
          "episodes": [
            {
              "id": "0D41096B-716D-4BE4-9D06-E7DC944DB761",
              "source_guid": "fixture-rome-1",
              "title": "The Fall of Rome: Part 1",
              "show_notes": "A fixture episode.",
              "audio_url": "https://example.com/rome-1.mp3",
              "published_at": "2026-07-01T12:00:00Z",
              "series_key": "fall-of-rome",
              "series_order": 1,
              "subjects": ["Rome", "Late Antiquity"]
            },
            {
              "id": "2E2FE7B1-A0B0-43DF-B73B-CFEC6EE71F13",
              "source_guid": "fixture-rome-2",
              "title": "The Fall of Rome: Part 2",
              "show_notes": "A fixture episode.",
              "audio_url": "https://example.com/rome-2.mp3",
              "published_at": "2026-07-02T12:00:00Z",
              "series_key": "fall-of-rome",
              "series_order": 2,
              "subjects": ["Rome", "Late Antiquity"]
            }
          ]
        },
        {
          "kind": "subject",
          "key": "napoleon",
          "title": "Napoleon",
          "topic": "France",
          "episodes": [
            {
              "id": "57C2ED3C-D1D3-43F1-8298-E9F9E10F81D7",
              "source_guid": "fixture-napoleon",
              "title": "Napoleon's Hundred Days",
              "show_notes": "A fixture episode.",
              "audio_url": "https://example.com/napoleon.mp3",
              "published_at": "2026-06-14T12:00:00Z",
              "series_key": null,
              "series_order": null,
              "subjects": ["Napoleon"]
            }
          ]
        },
        {
          "kind": "subject",
          "key": "tudors",
          "title": "The Tudors",
          "topic": "Great Britain",
          "episodes": [
            {
              "id": "14597584-9411-4638-8F50-6D761AA05D98",
              "source_guid": "fixture-tudors",
              "title": "Henry VIII and the Break with Rome",
              "show_notes": "A fixture episode.",
              "audio_url": "https://example.com/tudors.mp3",
              "published_at": "2026-05-20T12:00:00Z",
              "series_key": null,
              "series_order": null,
              "subjects": ["Tudors", "Reformation"]
            }
          ]
        },
        {
          "kind": "subject",
          "key": "aztecs",
          "title": "The Aztecs",
          "topic": "Mexico",
          "episodes": [
            {
              "id": "D3A06F3D-E7C0-4A41-9030-6C568C4B5350",
              "source_guid": "fixture-aztecs",
              "title": "The Rise of Tenochtitlan",
              "show_notes": "A fixture episode.",
              "audio_url": "https://example.com/aztecs.mp3",
              "published_at": "2026-04-11T12:00:00Z",
              "series_key": null,
              "series_order": null,
              "subjects": ["Aztecs"]
            }
          ]
        }
      ]
    }
    """#

  private static let smartPlaylistJSON = #"""
    {
      "schema_version": "1.0",
      "prompt": "Teach me Ancient Rome in chronological order",
      "scope": "catalogue",
      "planner": "openai",
      "fallback_used": false,
      "items": [
        {
          "episode_id": "0D41096B-716D-4BE4-9D06-E7DC944DB761",
          "podcast_id": "7F31CCEE-87A8-4E62-B3DB-0D5FE03C8E62",
          "podcast_title": "The Rest Is History",
          "episode_title": "The Fall of Rome: Part 1",
          "published_at": "2026-07-01T12:00:00Z",
          "series_key": "fall-of-rome",
          "series_order": 1,
          "reason": "Matched ancient Rome"
        },
        {
          "episode_id": "2E2FE7B1-A0B0-43DF-B73B-CFEC6EE71F13",
          "podcast_id": "7F31CCEE-87A8-4E62-B3DB-0D5FE03C8E62",
          "podcast_title": "The Rest Is History",
          "episode_title": "The Fall of Rome: Part 2",
          "published_at": "2026-07-02T12:00:00Z",
          "series_key": "fall-of-rome",
          "series_order": 2,
          "reason": "Matched ancient Rome"
        }
      ]
    }
    """#
}
