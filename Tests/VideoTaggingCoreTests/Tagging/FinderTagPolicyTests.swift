import Foundation
import XCTest

@testable import VideoTaggingCore

final class FinderTagPolicyTests: XCTestCase {
    func testManagedTagsUseFinderColorEntries() {
        XCTAssertEqual(ManagedTag.new.finderTagEntry, "New\n4")
        XCTAssertEqual(ManagedTag.watching.finderTagEntry, "Watching\n5")
        XCTAssertEqual(ManagedTag.viewed.finderTagEntry, "Viewed\n1")
    }

    func testTagUpdatePreservesUnmanagedTags() throws {
        let update = try XCTUnwrap(
            FinderTagPolicy.update(
                existingEntries: ["Family\n2", "Watching\n5"],
                with: .viewed,
                onlyIfUnmanaged: false
            ))
        XCTAssertEqual(update.retainedEntries, ["Family\n2"])
        XCTAssertEqual(update.updatedEntries, ["Family\n2", "Viewed\n1"])
        XCTAssertTrue(update.replacesManagedState)
    }

    func testIdenticalTagUpdateIsSkipped() {
        XCTAssertNil(
            FinderTagPolicy.update(
                existingEntries: ["Family\n2", "Viewed\n1"],
                with: .viewed,
                onlyIfUnmanaged: false
            ))
    }

    func testNewTagDoesNotReplaceManagedState() {
        XCTAssertNil(
            FinderTagPolicy.update(
                existingEntries: ["Watching\n5"],
                with: .new,
                onlyIfUnmanaged: true
            ))
    }

    func testSupportedMediaExtensions() {
        for path in ["movie.mkv", "movie.MP4", "movie.mov", "movie.m4v"] {
            XCTAssertTrue(TagManager.isSupportedMedia(URL(fileURLWithPath: path)))
        }
    }

    func testUnsupportedMediaExtensions() {
        for path in ["movie.avi", "movie", "movie.mp4.tmp"] {
            XCTAssertFalse(TagManager.isSupportedMedia(URL(fileURLWithPath: path)))
        }
    }
}
