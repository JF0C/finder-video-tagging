import Foundation
import XCTest

@testable import VideoTaggingCore

@MainActor
final class PlayerMonitorTests: XCTestCase {
    func testPublicInitializerAcceptsBrowserPlaybackClient() {
        let monitor = PlayerMonitor(
            tagManager: TagManager(),
            roots: [],
            viewedAtPercentage: nil,
            viewedSecondsBeforeEnd: nil,
            playbackResume: nil,
            browserPlaybackClient: BrowserPlaybackClientFake()
        )

        XCTAssertNotNil(monitor)
    }

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

    func testRouteRoundTripResumesCapturedBrowserSession() {
        var outputs = [output("tv"), output("pods"), output("speakers")]
        let browser = BrowserPlaybackClientFake()
        browser.snapshots = [browserSnapshot(sessionID: "playing")]
        let monitor = makeMonitor(
            playbackResume: resumeConfiguration(),
            items: { [] },
            currentOutput: { outputs.removeFirst() },
            browserPlaybackClient: browser
        )

        monitor.poll()
        monitor.poll()
        browser.snapshots = [browserSnapshot(sessionID: "new")]
        monitor.poll()

        XCTAssertEqual(browser.resumed.map(\.sessionID), ["playing"])
        XCTAssertEqual(browser.rewindSeconds, 5)
    }

    private func makeMonitor(
        playbackResume: PlaybackResumeConfiguration? = nil,
        items: @escaping () -> [PlaybackItem],
        currentOutput: @escaping () throws -> AudioOutputDevice? = { nil },
        setCurrentOutput: @escaping (String) throws -> Void = { _ in },
        applyTag: @escaping (ManagedTag, URL) -> Void = { _, _ in },
        resume: @escaping (PlaybackItem, Double) -> Void = { _, _ in },
        browserPlaybackClient: BrowserPlaybackClient? = nil
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
            ),
            browserPlaybackClient: browserPlaybackClient
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

    private func browserSnapshot(sessionID: String) -> BrowserMediaSnapshot {
        BrowserMediaSnapshot(
            identity: BrowserMediaIdentity(
                browser: .chrome,
                connectionID: "connection",
                tabID: 1,
                frameID: 0,
                documentID: "document",
                sessionID: sessionID
            ),
            isPlaying: true
        )
    }

    private func resumeConfiguration() -> PlaybackResumeConfiguration {
        PlaybackResumeConfiguration(
            targetOutput: ConfiguredAudioOutput(uid: "tv", name: "TV"),
            headphonesOutput: ConfiguredAudioOutput(uid: "pods", name: "AirPods"),
            rewindSeconds: 5
        )
    }
}

@MainActor
private final class BrowserPlaybackClientFake: BrowserPlaybackClient {
    var snapshots: [BrowserMediaSnapshot] = []
    var resumed: [BrowserMediaIdentity] = []
    var rewindSeconds: Double?

    func freshSnapshots() -> [BrowserMediaSnapshot] { snapshots }

    func resume(_ identities: [BrowserMediaIdentity], rewindSeconds: Double) {
        resumed = identities
        self.rewindSeconds = rewindSeconds
    }
}
