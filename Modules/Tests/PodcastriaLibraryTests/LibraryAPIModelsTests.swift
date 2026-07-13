import Foundation
import Testing
@testable import PodcastriaLibrary

@Test func decodesVersionedCatalogue() throws {
    let data = Data(
        """
        {
          "schema_version": "1.1",
          "product_name": "Podcastria Library",
          "podcasts": [{
            "id": "11111111-1111-1111-1111-111111111111",
            "title": "The Rest Is History",
            "description": "A curated history show"
          }],
          "pagination": {"offset": 0, "limit": 20, "returned": 1}
        }
        """.utf8
    )

    let response = try JSONDecoder().decode(CatalogueResponse.self, from: data)

    #expect(response.productName == "Podcastria Library")
    #expect(response.podcasts.first?.title == "The Rest Is History")
    #expect(response.pagination.returned == 1)
}

@Test func decodesOrganisedPodcastDetailAndPlaybackIdentity() throws {
    let data = Data(
        """
        {
          "schema_version": "1.0",
          "id": "11111111-1111-1111-1111-111111111111",
          "title": "The Rest Is History",
          "description": "A curated history show",
          "groups": [{
            "kind": "series",
            "key": "fall-of-rome",
            "title": "The Fall of Rome",
            "topic": "Ancient Rome",
            "episodes": [{
              "id": "22222222-2222-2222-2222-222222222222",
              "source_guid": "publisher-guid-1",
              "title": "Part one",
              "show_notes": null,
              "audio_url": "https://audio.example/part-one.mp3",
              "published_at": "2026-07-10T10:00:00Z",
              "series_key": "fall-of-rome",
              "series_order": 1,
              "subjects": ["Ancient Rome"]
            }]
          }]
        }
        """.utf8
    )
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let response = try decoder.decode(PodcastDetailResponse.self, from: data)
    let episode = try #require(response.groups.first?.episodes.first)

    #expect(response.groups.first?.kind == .series)
    #expect(response.groups.first?.topic == "Ancient Rome")
    #expect(episode.sourceGUID == "publisher-guid-1")
    #expect(episode.audioURL?.absoluteString == "https://audio.example/part-one.mp3")
    #expect(episode.seriesOrder == 1)
}

@Test func fuzzySearchMatchesGroupAndEpisodeTypos() throws {
    let episode = EpisodeSummary(
        id: UUID(),
        sourceGUID: "watergate-1",
        title: "The Watergate Break-in",
        showNotes: nil,
        audioURL: nil,
        publishedAt: nil,
        seriesKey: "Watergate",
        seriesOrder: 1,
        subjects: []
    )
    let group = EpisodeGroup(
        kind: .series,
        key: "Watergate",
        title: "Watergate",
        topic: "America",
        episodes: [episode]
    )

    #expect(LibraryFuzzySearch.groups([group], matching: "watreagte").count == 1)
    #expect(LibraryFuzzySearch.groups([group], matching: "break in").first?.episodes == [episode])
    #expect(LibraryFuzzySearch.groups([group], matching: "samurai").isEmpty)
}
