import Foundation
import XCTest

@testable import VideoTaggingCore

final class PlaybackPolicyTests: XCTestCase {
    func testParsingSkipsMalformedLines() {
        let output = "/videos/one.mp4\t42.5\t100\ttrue\ninvalid\n/videos/two.mkv\t3\t8\tfalse"
        let items = PlaybackPolicy.parse(output, player: .vlc)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].url.path, "/videos/one.mp4")
        XCTAssertEqual(items[0].currentTime, 42.5)
        XCTAssertTrue(items[0].isPlaying)
        XCTAssertFalse(items[1].isPlaying)
    }

    func testViewedWhenEitherCriterionMatches() {
        let item = playbackItem(currentTime: 85, duration: 100)
        XCTAssertEqual(
            PlaybackPolicy.tag(
                for: item,
                viewedAtPercentage: 85,
                viewedSecondsBeforeEnd: nil
            ), .viewed)
        XCTAssertEqual(
            PlaybackPolicy.tag(
                for: item,
                viewedAtPercentage: nil,
                viewedSecondsBeforeEnd: 15
            ), .viewed)
    }

    func testWatchingBeforeCompletionAndNilForInvalidPlayback() {
        XCTAssertEqual(
            PlaybackPolicy.tag(
                for: playbackItem(currentTime: 20, duration: 100),
                viewedAtPercentage: 85,
                viewedSecondsBeforeEnd: 10
            ), .watching)
        XCTAssertNil(
            PlaybackPolicy.tag(
                for: playbackItem(currentTime: 0, duration: 0),
                viewedAtPercentage: 85,
                viewedSecondsBeforeEnd: nil
            ))
    }

    func testObservedFoldersMatchAtPathBoundaries() {
        let roots = [URL(fileURLWithPath: "/videos")]
        XCTAssertTrue(
            PlaybackPolicy.isObserved(
                URL(fileURLWithPath: "/videos/movie.mp4"), roots: roots))
        XCTAssertTrue(PlaybackPolicy.isObserved(URL(fileURLWithPath: "/videos"), roots: roots))
        XCTAssertFalse(
            PlaybackPolicy.isObserved(
                URL(fileURLWithPath: "/videos-old/movie.mp4"), roots: roots))
    }

    func testRewindTimeCannotBeNegative() {
        XCTAssertEqual(PlaybackPolicy.resumeTime(currentTime: 3, rewindSeconds: 5), 0)
        XCTAssertEqual(PlaybackPolicy.resumeTime(currentTime: 10, rewindSeconds: 5), 5)
    }

    private func playbackItem(currentTime: Double, duration: Double) -> PlaybackItem {
        PlaybackItem(
            player: .quickTime,
            url: URL(fileURLWithPath: "/videos/movie.mp4"),
            currentTime: currentTime,
            duration: duration,
            isPlaying: true
        )
    }
}
