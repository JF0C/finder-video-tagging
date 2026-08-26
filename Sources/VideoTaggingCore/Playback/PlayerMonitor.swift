import Foundation

@MainActor
public final class PlayerMonitor {
    private let roots: [URL]
    private let viewedAtPercentage: Double?
    private let viewedSecondsBeforeEnd: Double?
    private let playbackResume: PlaybackResumeConfiguration?
    private let dependencies: PlayerMonitorDependencies
    private var resumeCoordinator = PlaybackResumeCoordinator()

    public init(
        tagManager: TagManager,
        roots: [URL],
        viewedAtPercentage: Double?,
        viewedSecondsBeforeEnd: Double?,
        playbackResume: PlaybackResumeConfiguration?
    ) {
        self.roots = roots.map(\.standardizedFileURL)
        self.viewedAtPercentage = viewedAtPercentage
        self.viewedSecondsBeforeEnd = viewedSecondsBeforeEnd
        self.playbackResume = playbackResume
        self.dependencies = .live(tagManager: tagManager)
    }

    init(
        roots: [URL],
        viewedAtPercentage: Double?,
        viewedSecondsBeforeEnd: Double?,
        playbackResume: PlaybackResumeConfiguration?,
        dependencies: PlayerMonitorDependencies
    ) {
        self.roots = roots.map(\.standardizedFileURL)
        self.viewedAtPercentage = viewedAtPercentage
        self.viewedSecondsBeforeEnd = viewedSecondsBeforeEnd
        self.playbackResume = playbackResume
        self.dependencies = dependencies
    }

    public func poll() {
        let items = dependencies.items()
        handleAudioRouteChange(items: items)
        for item in items {
            guard dependencies.isSupportedMedia(item.url),
                PlaybackPolicy.isObserved(item.url, roots: roots),
                let tag = PlaybackPolicy.tag(
                    for: item,
                    viewedAtPercentage: viewedAtPercentage,
                    viewedSecondsBeforeEnd: viewedSecondsBeforeEnd
                )
            else { continue }
            dependencies.applyTag(tag, item.url)
        }
    }

    private func handleAudioRouteChange(items: [PlaybackItem]) {
        guard let playbackResume, let output = try? dependencies.currentOutput() else { return }
        let action = resumeCoordinator.outputChanged(
            to: output.uid,
            items: items,
            configuration: playbackResume
        )
        guard case let .restore(targetUID, pendingItems, rewindSeconds) = action else { return }
        do {
            try dependencies.setCurrentOutput(targetUID)
            dependencies.scheduleResume { [weak self] in
                self?.resume(pendingItems, rewindSeconds: rewindSeconds)
            }
        } catch {
            dependencies.reportError("Could not restore audio output: \(error)")
        }
    }

    private func resume(_ pendingItems: [PlaybackItem], rewindSeconds: Double) {
        let currentItems = dependencies.items()
        for pendingItem in pendingItems {
            guard
                let current = currentItems.first(where: {
                    $0.player == pendingItem.player && $0.url == pendingItem.url && !$0.isPlaying
                })
            else { continue }
            dependencies.resume(
                current,
                PlaybackPolicy.resumeTime(
                    currentTime: current.currentTime,
                    rewindSeconds: rewindSeconds
                )
            )
        }
    }
}
