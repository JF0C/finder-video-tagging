import Foundation
import XCTest

@testable import VideoTaggingCore

final class FolderWatcherPolicyTests: XCTestCase {
    func testMissingPathProducesNoMedia() {
        let media = FolderWatcherPolicy.mediaURLs(
            at: URL(fileURLWithPath: "/missing"),
            fileExists: false,
            isSupportedMedia: { _ in true },
            descendants: {
                XCTFail("Should not enumerate a missing path")
                return []
            }
        )

        XCTAssertTrue(media.isEmpty)
    }

    func testSupportedFileIsReturnedWithoutEnumeratingDescendants() {
        let url = URL(fileURLWithPath: "/videos/movie.mp4")
        let media = FolderWatcherPolicy.mediaURLs(
            at: url,
            fileExists: true,
            isSupportedMedia: { $0.pathExtension == "mp4" },
            descendants: {
                XCTFail("Should not enumerate a media file")
                return []
            }
        )

        XCTAssertEqual(media, [url])
    }

    func testDirectoryReturnsOnlySupportedDescendants() {
        let movie = URL(fileURLWithPath: "/videos/movie.mkv")
        let text = URL(fileURLWithPath: "/videos/notes.txt")
        let media = FolderWatcherPolicy.mediaURLs(
            at: URL(fileURLWithPath: "/videos"),
            fileExists: true,
            isSupportedMedia: { ["mkv", "mp4"].contains($0.pathExtension) },
            descendants: { [movie, text] }
        )

        XCTAssertEqual(media, [movie])
    }

    func testUnavailableFileStateStops() {
        XCTAssertEqual(
            FolderWatcherPolicy.stabilityAction(
                initialSize: nil, fileExists: true, currentSize: 10, attemptsRemaining: 2),
            .stop)
        XCTAssertEqual(
            FolderWatcherPolicy.stabilityAction(
                initialSize: 10, fileExists: false, currentSize: 10, attemptsRemaining: 2),
            .stop)
        XCTAssertEqual(
            FolderWatcherPolicy.stabilityAction(
                initialSize: 10, fileExists: true, currentSize: nil, attemptsRemaining: 2),
            .stop)
    }

    func testStableFileIsTagged() {
        XCTAssertEqual(
            FolderWatcherPolicy.stabilityAction(
                initialSize: 10, fileExists: true, currentSize: 10, attemptsRemaining: 1),
            .tag)
    }

    func testChangingFileRetriesBeforeTimingOut() {
        XCTAssertEqual(
            FolderWatcherPolicy.stabilityAction(
                initialSize: 10, fileExists: true, currentSize: 20, attemptsRemaining: 2),
            .retry)
        XCTAssertEqual(
            FolderWatcherPolicy.stabilityAction(
                initialSize: 10, fileExists: true, currentSize: 20, attemptsRemaining: 1),
            .timedOut)
    }
}
