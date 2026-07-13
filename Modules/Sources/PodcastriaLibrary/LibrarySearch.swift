import Foundation

enum LibraryFuzzySearch {
    static func groups(_ groups: [EpisodeGroup], matching query: String) -> [EpisodeGroup] {
        let query = normalise(query)
        guard !query.isEmpty else { return groups }

        return groups.compactMap { group in
            if matches(query, candidate: group.title) || matches(query, candidate: group.topic) {
                return group
            }

            let episodes = group.episodes.filter { episode in
                matches(query, candidate: episode.title)
                    || matches(query, candidate: episode.showNotes ?? "")
            }
            guard !episodes.isEmpty else { return nil }
            return EpisodeGroup(
                kind: group.kind,
                key: group.key,
                title: group.title,
                topic: group.topic,
                episodes: episodes
            )
        }
    }

    static func matches(_ query: String, candidate: String) -> Bool {
        let query = normalise(query)
        let candidate = normalise(candidate)
        guard !query.isEmpty, !candidate.isEmpty else { return false }
        if candidate.contains(query) { return true }

        let candidateWords = candidate.split(separator: " ").map(String.init)
        return query.split(separator: " ").allSatisfy { token in
            candidateWords.contains { word in
                let allowedDistance = max(1, token.count / 4)
                return editDistance(String(token), word) <= allowedDistance
            }
        }
    }

    private static func normalise(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhs = Array(lhs)
        let rhs = Array(rhs)
        var distances = Array(
            repeating: Array(repeating: 0, count: rhs.count + 1),
            count: lhs.count + 1
        )
        for lhsIndex in 0 ... lhs.count {
            distances[lhsIndex][0] = lhsIndex
        }
        for rhsIndex in 0 ... rhs.count {
            distances[0][rhsIndex] = rhsIndex
        }

        for lhsIndex in 1 ... lhs.count {
            for rhsIndex in 1 ... rhs.count {
                let substitutionCost = lhs[lhsIndex - 1] == rhs[rhsIndex - 1] ? 0 : 1
                var distance = min(
                    distances[lhsIndex - 1][rhsIndex] + 1,
                    distances[lhsIndex][rhsIndex - 1] + 1,
                    distances[lhsIndex - 1][rhsIndex - 1] + substitutionCost
                )
                if lhsIndex > 1,
                   rhsIndex > 1,
                   lhs[lhsIndex - 1] == rhs[rhsIndex - 2],
                   lhs[lhsIndex - 2] == rhs[rhsIndex - 1] {
                    distance = min(distance, distances[lhsIndex - 2][rhsIndex - 2] + 1)
                }
                distances[lhsIndex][rhsIndex] = distance
            }
        }
        return distances[lhs.count][rhs.count]
    }
}
