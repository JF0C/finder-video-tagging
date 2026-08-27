import Foundation
import XCTest

@testable import VideoTaggingCore

final class BrowserMediaRegistryTests: XCTestCase {
    func testReturnsFreshPlayingAndPausedSnapshots() throws {
        var registry = BrowserMediaRegistry()
        registry.update(try message(sessionID: "playing", isPlaying: true), receivedAt: 10)
        registry.update(try message(sessionID: "paused", isPlaying: false), receivedAt: 11)

        let snapshots = registry.freshSnapshots(at: 13)

        XCTAssertEqual(Set(snapshots.map(\.identity.sessionID)), ["playing", "paused"])
        XCTAssertEqual(snapshots.filter(\.isPlaying).map(\.identity.sessionID), ["playing"])
    }

    func testExpiresStaleSnapshots() throws {
        var registry = BrowserMediaRegistry()
        registry.update(try message(sessionID: "stale"), receivedAt: 10)

        XCTAssertTrue(registry.freshSnapshots(at: 13.01).isEmpty)
        XCTAssertFalse(registry.contains(identity(sessionID: "stale")))
    }

    func testRemovalAndDisconnectClearExactEntries() throws {
        var registry = BrowserMediaRegistry()
        registry.update(try message(sessionID: "removed"), receivedAt: 10)
        registry.update(try message(sessionID: "connected"), receivedAt: 10)
        registry.update(try message(sessionID: "removed", event: "removed"), receivedAt: 11)
        registry.disconnect(connectionID: "connection")

        XCTAssertTrue(registry.freshSnapshots(at: 11).isEmpty)
    }

    func testRejectsWrongVersionAndInvalidTime() throws {
        var registry = BrowserMediaRegistry()
        registry.update(try message(sessionID: "old", version: 2), receivedAt: 10)
        registry.update(try message(sessionID: "invalid", currentTime: -1), receivedAt: 10)

        XCTAssertTrue(registry.freshSnapshots(at: 10).isEmpty)
    }

    private func message(
        sessionID: String,
        version: Int = BrowserProtocol.version,
        event: String = "playing",
        isPlaying: Bool = true,
        currentTime: Double = 20
    ) throws -> BrowserMediaStateMessage {
        let data = try JSONSerialization.data(withJSONObject: [
            "version": version, "type": "media-state", "browser": "firefox",
            "connectionId": "connection", "tabId": 1, "frameId": 0,
            "documentId": "document", "sessionId": sessionID, "event": event,
            "isPlaying": isPlaying, "ended": false, "currentTime": currentTime,
            "duration": 100,
        ])
        return try JSONDecoder().decode(BrowserMediaStateMessage.self, from: data)
    }

    private func identity(sessionID: String) -> BrowserMediaIdentity {
        BrowserMediaIdentity(
            browser: .firefox,
            connectionID: "connection",
            tabID: 1,
            frameID: 0,
            documentID: "document",
            sessionID: sessionID
        )
    }
}
