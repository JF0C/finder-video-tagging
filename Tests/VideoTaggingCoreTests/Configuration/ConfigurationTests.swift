import Foundation
import XCTest

@testable import VideoTaggingCore

final class ConfigurationTests: XCTestCase {
    func testMissingConfigurationUsesAvailableDefaults() {
        let configuration = Configuration.resolve(
            data: nil,
            homeDirectory: URL(fileURLWithPath: "/Users/test", isDirectory: true),
            fileExists: { $0.hasSuffix("/Downloads") }
        )
        XCTAssertEqual(configuration.observedFolders, ["/Users/test/Downloads"])
        XCTAssertEqual(configuration.viewedAtPercentage, 85)
        XCTAssertNil(configuration.viewedSecondsBeforeEnd)
    }

    func testConfigurationRemovesMissingAndDuplicateFolders() throws {
        let input = Configuration(
            observedFolders: ["/videos", "/videos/", "/missing"],
            viewedAtPercentage: 90,
            viewedSecondsBeforeEnd: 20,
            playbackResume: nil
        )
        let configuration = Configuration.resolve(
            data: try JSONEncoder().encode(input),
            homeDirectory: URL(fileURLWithPath: "/Users/test"),
            fileExists: { $0 == "/videos" }
        )
        XCTAssertEqual(configuration.observedFolders, ["/videos"])
        XCTAssertEqual(configuration.viewedAtPercentage, 90)
        XCTAssertEqual(configuration.viewedSecondsBeforeEnd, 20)
    }

    func testMissingFoldersFallBackWithoutLosingCriteria() throws {
        let input = Configuration(
            observedFolders: ["/missing"],
            viewedAtPercentage: nil,
            viewedSecondsBeforeEnd: 15,
            playbackResume: nil
        )
        var messages: [String] = []
        let configuration = Configuration.resolve(
            data: try JSONEncoder().encode(input),
            homeDirectory: URL(fileURLWithPath: "/Users/test"),
            fileExists: { $0.hasSuffix("/Movies") },
            report: { messages.append($0) }
        )
        XCTAssertEqual(configuration.observedFolders, ["/Users/test/Movies"])
        XCTAssertEqual(configuration.viewedAtPercentage, 85)
        XCTAssertEqual(configuration.viewedSecondsBeforeEnd, 15)
        XCTAssertEqual(
            messages, ["No configured observed folders exist; using Downloads and Movies."])
    }
}
