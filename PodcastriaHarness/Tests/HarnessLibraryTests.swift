import Foundation
import Testing

@Test func decodesCatalogueContract() throws {
  let data = Data(
    #"""
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
    """#.utf8
  )

  let response = try JSONDecoder().decode(CatalogueResponse.self, from: data)

  #expect(response.productName == "Podcastria Library")
  #expect(response.podcasts.first?.title == "The Rest Is History")
  #expect(response.pagination.returned == 1)
}

@Test func fuzzySearchMatchesTyposAndEpisodeTitles() throws {
  let data = Data(
    #"""
    {
      "schema_version": "1.1",
      "id": "11111111-1111-1111-1111-111111111111",
      "title": "The Rest Is History",
      "description": null,
      "groups": [{
        "kind": "series",
        "key": "watergate",
        "title": "Watergate",
        "topic": "America",
        "episodes": [{
          "id": "22222222-2222-2222-2222-222222222222",
          "source_guid": "watergate-1",
          "title": "The Watergate Break-in",
          "show_notes": null,
          "audio_url": null,
          "published_at": null,
          "series_key": "watergate",
          "series_order": 1,
          "subjects": []
        }]
      }]
    }
    """#.utf8
  )
  let detail = try JSONDecoder().decode(PodcastDetailResponse.self, from: data)

  #expect(LibraryFuzzySearch.groups(detail.groups, matching: "watreagte").count == 1)
  #expect(LibraryFuzzySearch.groups(detail.groups, matching: "break in").count == 1)
  #expect(LibraryFuzzySearch.groups(detail.groups, matching: "samurai").isEmpty)
}
