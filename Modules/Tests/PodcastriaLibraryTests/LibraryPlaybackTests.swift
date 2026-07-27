import Foundation
import Testing
@testable import PodcastriaLibrary

@Test func playbackRequestCarriesPodcastContext() throws {
    let data = Data(
        """
        {
          "schema_version": "1.1",
          "id": "22222222-2222-2222-2222-222222222222",
          "title": "The Rest Is History",
          "description": "A curated history show",
          "groups": [{
            "kind": "series",
            "key": "punic-wars",
            "title": "The Punic Wars",
            "topic": "Rome",
            "episodes": [{
              "id": "33333333-3333-3333-3333-333333333333",
              "source_guid": "guid-1",
              "title": "Hannibal Crosses the Alps",
              "audio_url": "https://audio.example.com/hannibal.mp3",
              "series_order": 3,
              "subjects": ["Rome"]
            }]
          }]
        }
        """.utf8
    )

    let podcast = try JSONDecoder().decode(PodcastDetailResponse.self, from: data)
    let episode = try #require(podcast.groups.first?.episodes.first)

    let request = podcast.playbackRequest(for: episode)

    #expect(request.podcastID == podcast.id)
    #expect(request.podcastTitle == "The Rest Is History")
    #expect(request.podcastDescription == "A curated history show")
    #expect(request.episode.id == episode.id)
    #expect(request.episode.audioURL?.absoluteString == "https://audio.example.com/hannibal.mp3")
}
