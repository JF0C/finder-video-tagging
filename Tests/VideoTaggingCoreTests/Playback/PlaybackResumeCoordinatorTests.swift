import Foundation
import XCTest

@testable import VideoTaggingCore

final class PlaybackResumeCoordinatorTests: XCTestCase {
    func testRouteRoundTripRestoresOnlyCapturedPlayingItems() {
        var coordinator = PlaybackResumeCoordinator()
        let configuration = resumeConfiguration()
        let playing = item(path: "/videos/playing.mp4", isPlaying: true)
        let paused = item(path: "/videos/paused.mp4", isPlaying: false)
        XCTAssertEqual(
            coordinator.outputChanged(
                to: "tv", items: [], configuration: configuration), .none)
        XCTAssertEqual(
            coordinator.outputChanged(
                to: "pods", items: [playing, paused], configuration: configuration), .none)
        XCTAssertEqual(
            coordinator.outputChanged(
                to: "speakers", items: [], configuration: configuration),
            .restore(
                targetUID: "tv",
                localItems: [playing],
                browserSessions: [],
                rewindSeconds: 5
            ))
    }

    func testRouteRoundTripCapturesOnlyPlayingBrowserSessions() {
        var coordinator = PlaybackResumeCoordinator()
        let playing = browserSnapshot(sessionID: "playing", isPlaying: true)
        let paused = browserSnapshot(sessionID: "paused", isPlaying: false)
        _ = coordinator.outputChanged(to: "tv", items: [], configuration: resumeConfiguration())
        _ = coordinator.outputChanged(
            to: "pods",
            items: [],
            browserMedia: [playing, paused],
            configuration: resumeConfiguration()
        )

        XCTAssertEqual(
            coordinator.outputChanged(
                to: "speakers", items: [], configuration: resumeConfiguration()),
            .restore(
                targetUID: "tv",
                localItems: [],
                browserSessions: [playing.identity],
                rewindSeconds: 5
            ))
        XCTAssertEqual(
            coordinator.outputChanged(
                to: "tv", items: [], configuration: resumeConfiguration()),
            .none
        )
    }

    func testUnrelatedRouteChangesDoNothing() {
        var coordinator = PlaybackResumeCoordinator()
        let configuration = resumeConfiguration()
        _ = coordinator.outputChanged(to: "speakers", items: [], configuration: configuration)
        XCTAssertEqual(
            coordinator.outputChanged(
                to: "tv",
                items: [item(path: "/videos/movie.mp4", isPlaying: true)],
                configuration: configuration
            ), .none)
    }

    private func resumeConfiguration() -> PlaybackResumeConfiguration {
        PlaybackResumeConfiguration(
            targetOutput: ConfiguredAudioOutput(uid: "tv", name: "TV"),
            headphonesOutput: ConfiguredAudioOutput(uid: "pods", name: "AirPods"),
            rewindSeconds: 5
        )
    }

    private func item(path: String, isPlaying: Bool) -> PlaybackItem {
        PlaybackItem(
            player: .vlc,
            url: URL(fileURLWithPath: path),
            currentTime: 20,
            duration: 100,
            isPlaying: isPlaying
        )
    }

    private func browserSnapshot(sessionID: String, isPlaying: Bool) -> BrowserMediaSnapshot {
        BrowserMediaSnapshot(
            identity: BrowserMediaIdentity(
                browser: .firefox,
                connectionID: "connection",
                tabID: 1,
                frameID: 0,
                documentID: "document",
                sessionID: sessionID
            ),
            isPlaying: isPlaying
        )
    }
}
