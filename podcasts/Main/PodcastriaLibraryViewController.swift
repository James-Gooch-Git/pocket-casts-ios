import PocketCastsDataModel
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
            onSelectEpisode: { [weak self] episode in
                Task { @MainActor in
                    self?.playbackAdapter.play(episode, presentingFrom: self)
                }
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
private final class PodcastriaPlaybackAdapter {
    private let mappings = PodcastriaEpisodeIdentityStore()
    private let dataManager = DataManager.sharedManager

    func play(_ summary: EpisodeSummary, presentingFrom controller: UIViewController?) {
        guard let episode = resolve(summary) else {
            let alert = UIAlertController(
                title: "Episode unavailable",
                message: "This curated episode is not yet available in your local podcast library.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.ok, style: .default))
            controller?.present(alert, animated: true)
            return
        }

        PlaybackManager.shared.load(episode: episode, autoPlay: true, overrideUpNext: false)
    }

    private func resolve(_ summary: EpisodeSummary) -> BaseEpisode? {
        if let localUUID = mappings.localUUID(for: summary.id),
           let episode = dataManager.findBaseEpisode(uuid: localUUID) {
            return episode
        } else {
            mappings.remove(backendUUID: summary.id)
        }

        guard let audioURL = summary.audioURL?.absoluteString else {
            return nil
        }
        let candidates = dataManager.findEpisodesWhere(customWhere: "downloadUrl = ?", arguments: [audioURL])
        guard candidates.count == 1, let episode = candidates.first else { return nil }

        mappings.set(localUUID: episode.uuid, for: summary.id)
        return episode
    }
}

private struct PodcastriaEpisodeIdentityStore {
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
