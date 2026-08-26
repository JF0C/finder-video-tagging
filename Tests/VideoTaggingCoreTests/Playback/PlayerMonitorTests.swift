import Foundation
import XCTest

@testable import VideoTaggingCore

@MainActor
final class PlayerMonitorTests: XCTestCase {
    func testPollTagsOnlySupportedPlayingItemsInObservedFolders() {
        let items = [
            item(path: "/videos/watching.mp4", currentTime: 20),
            item(path: "/videos/viewed.mkv", currentTime: 90),
            item(path: "/other/outside.mp4", currentTime: 90),
            item(path: "/videos/unsupported.avi", currentTime: 90),
        ]
        var applied: [(ManagedTag, String)] = []
        let monitor = makeMonitor(
            items: { items },
            applyTag: { applied.append(($0, $1.path)) }
        )

        monitor.poll()

        XCTAssertEqual(applied.map(\.0), [.watching, .viewed])
        XCTAssertEqual(applied.map(\.1), ["/videos/watching.mp4", "/videos/viewed.mkv"])
    }

    func testRouteRoundTripRestoresOutputAndResumesPausedItem() {
        let playing = item(path: "/videos/movie.mp4", currentTime: 30)
        let paused = item(path: "/videos/movie.mp4", currentTime: 28, isPlaying: false)
        var itemReads = 0
        var outputs = [output("tv"), output("pods"), output("speakers")]
        var restoredUID: String?
        var resumed: (PlaybackItem, Double)?
        let monitor = makeMonitor(
            playbackResume: resumeConfiguration(),
            items: {
                itemReads += 1
                return itemReads <= 3 ? [playing] : [paused]
            },
            currentOutput: { outputs.removeFirst() },
            setCurrentOutput: { restoredUID = $0 },
            resume: { resumed = ($0, $1) }
        )

        monitor.poll()
        monitor.poll()
        monitor.poll()

        XCTAssertEqual(restoredUID, "tv")
        XCTAssertEqual(resumed?.0.url, paused.url)
        XCTAssertEqual(resumed?.1, 23)
    }

    private func makeMonitor(
        playbackResume: PlaybackResumeConfiguration? = nil,
        items: @escaping () -> [PlaybackItem],
        currentOutput: @escaping () throws -> AudioOutputDevice? = { nil },
        setCurrentOutput: @escaping (String) throws -> Void = { _ in },
        applyTag: @escaping (ManagedTag, URL) -> Void = { _, _ in },
        resume: @escaping (PlaybackItem, Double) -> Void = { _, _ in }
    ) -> PlayerMonitor {
        PlayerMonitor(
            roots: [URL(fileURLWithPath: "/videos")],
            viewedAtPercentage: 85,
            viewedSecondsBeforeEnd: nil,
            playbackResume: playbackResume,
            dependencies: PlayerMonitorDependencies(
                items: items,
                isSupportedMedia: TagManager.isSupportedMedia,
                applyTag: applyTag,
                currentOutput: currentOutput,
                setCurrentOutput: setCurrentOutput,
                scheduleResume: { $0() },
                resume: resume,
                reportError: { _ in }
            )
        )
    }

    private func item(
        path: String,
        currentTime: Double,
        isPlaying: Bool = true
    ) -> PlaybackItem {
        PlaybackItem(
            player: .vlc,
            url: URL(fileURLWithPath: path),
            currentTime: currentTime,
            duration: 100,
            isPlaying: isPlaying
        )
    }

    private func output(_ uid: String) -> AudioOutputDevice {
        AudioOutputDevice(uid: uid, name: uid, transportType: 0)
    }

    private func resumeConfiguration() -> PlaybackResumeConfiguration {
        PlaybackResumeConfiguration(
            targetOutput: ConfiguredAudioOutput(uid: "tv", name: "TV"),
            headphonesOutput: ConfiguredAudioOutput(uid: "pods", name: "AirPods"),
            rewindSeconds: 5
        )
    }
}
