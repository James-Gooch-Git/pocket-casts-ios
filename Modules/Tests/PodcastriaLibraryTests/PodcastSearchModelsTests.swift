import Foundation
import Testing
@testable import PodcastriaLibrary

@Test func decodesSearchResponse() throws {
    let data = Data(
        """
        {
          "results": [
            {
              "id": "pc-12345",
              "title": "The Rest Is History",
              "author": "Goalhanger Podcasts",
              "description": "The world's most popular history podcast.",
              "feed_url": "https://feeds.megaphone.fm/restishistory",
              "artwork_url": "https://example.com/artwork.jpg",
              "episode_count": 450,
              "last_published": "2026-07-20T12:00:00Z"
            },
            {
              "id": "pc-67890",
              "title": "Revolutions",
              "feed_url": "https://example.com/revolutions.xml"
            }
          ]
        }
        """.utf8
    )

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let response = try decoder.decode(PodcastSearchResponse.self, from: data)

    #expect(response.results.count == 2)

    let first = response.results[0]
    #expect(first.id == "pc-12345")
    #expect(first.title == "The Rest Is History")
    #expect(first.author == "Goalhanger Podcasts")
    #expect(first.feedURL == "https://feeds.megaphone.fm/restishistory")
    #expect(first.episodeCount == 450)

    let second = response.results[1]
    #expect(second.author == nil)
    #expect(second.artworkURL == nil)
    #expect(second.episodeCount == nil)
}

@Test func encodesSearchRequest() throws {
    let request = PodcastSearchRequest(query: "roman history", limit: 10)
    let data = try JSONEncoder().encode(request)
    let decoded = try JSONDecoder().decode(PodcastSearchRequest.self, from: data)
    #expect(decoded == request)
}

@Test func encodesSubscribeRequest() throws {
    let request = SubscribeRequest(feedURL: "https://feeds.megaphone.fm/restishistory")
    let data = try JSONEncoder().encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(json["feed_url"] as? String == "https://feeds.megaphone.fm/restishistory")
}

@Test func decodesSubscribeResponse() throws {
    let data = Data(
        """
        {
          "podcast_uuid": "7F31CCEE-87A8-4E62-B3DB-0D5FE03C8E62",
          "title": "The Rest Is History",
          "episodes_added": 25
        }
        """.utf8
    )

    let response = try JSONDecoder().decode(SubscribeResponse.self, from: data)
    #expect(response.podcastUUID == "7F31CCEE-87A8-4E62-B3DB-0D5FE03C8E62")
    #expect(response.title == "The Rest Is History")
    #expect(response.episodesAdded == 25)
}
